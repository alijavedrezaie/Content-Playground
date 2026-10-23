-- Run once in the Supabase SQL Editor. Existing browser plans are not modified.
begin;
create table public.planner_workspaces (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references auth.users(id) on delete cascade,
 name text not null check(length(name) between 1 and 100),
 kind text not null check(kind in ('personal','team')),
 created_at timestamptz not null default now()
);
create unique index planner_one_personal on public.planner_workspaces(owner_id) where kind='personal';
create table public.planner_members (
 workspace_id uuid not null references public.planner_workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 primary key(workspace_id,user_id)
);
create table public.planner_invitations (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.planner_workspaces(id) on delete cascade,
 email text not null,
 created_at timestamptz not null default now(),
 unique(workspace_id,email)
);
create table public.planner_documents (
 workspace_id uuid primary key references public.planner_workspaces(id) on delete cascade,
 payload jsonb not null,
 revision bigint not null default 1,
 updated_at timestamptz not null default now(),
 updated_by uuid not null references auth.users(id)
);
alter table public.planner_workspaces enable row level security;
alter table public.planner_members enable row level security;
alter table public.planner_invitations enable row level security;
alter table public.planner_documents enable row level security;

create function public.planner_can_access(p_workspace uuid) returns boolean
language sql stable security definer set search_path=pg_catalog,public as $$
 select auth.uid() is not null and exists (
 select 1 from public.planner_workspaces w where w.id=p_workspace and
 (w.owner_id=auth.uid() or (w.kind='team' and exists (
 select 1 from public.planner_members m where m.workspace_id=w.id and m.user_id=auth.uid()))));
$$;
create policy workspace_read on public.planner_workspaces for select to authenticated using(public.planner_can_access(id));
create policy member_read on public.planner_members for select to authenticated using(public.planner_can_access(workspace_id));
create policy document_read on public.planner_documents for select to authenticated using(public.planner_can_access(workspace_id));
create policy invitation_read on public.planner_invitations for select to authenticated using(
 exists(select 1 from public.planner_workspaces w where w.id=workspace_id and w.owner_id=auth.uid())
 or email=lower(auth.jwt()->>'email')
);

create function public.planner_personal_workspace() returns uuid
language plpgsql security definer set search_path=pg_catalog,public as $$
declare result uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 insert into public.planner_workspaces(owner_id,name,kind) values(auth.uid(),'My private plans','personal')
 on conflict(owner_id) where kind='personal' do nothing;
 select id into result from public.planner_workspaces where owner_id=auth.uid() and kind='personal';
 return result;
end; $$;
create function public.planner_create_team(p_name text) returns uuid
language plpgsql security definer set search_path=pg_catalog,public as $$
declare result uuid;
begin
 if auth.uid() is null then raise exception 'Sign in required'; end if;
 if length(trim(p_name)) not between 1 and 100 then raise exception 'Choose a team name of 1 to 100 characters'; end if;
 insert into public.planner_workspaces(owner_id,name,kind) values(auth.uid(),trim(p_name),'team') returning id into result;
 return result;
end; $$;
create function public.planner_invite(p_workspace uuid,p_email text) returns void
language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 if not exists(select 1 from public.planner_workspaces where id=p_workspace and owner_id=auth.uid() and kind='team') then raise exception 'Only the team owner can invite members'; end if;
 if length(trim(p_email))>254 or trim(p_email) !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then raise exception 'Enter a valid email address'; end if;
 insert into public.planner_invitations(workspace_id,email) values(p_workspace,lower(trim(p_email))) on conflict do nothing;
end; $$;
create function public.planner_pending_invites() returns table(id uuid,team_name text)
language sql stable security definer set search_path=pg_catalog,public as $$
 select i.id,w.name from public.planner_invitations i join public.planner_workspaces w on w.id=i.workspace_id
 join auth.users u on u.id=auth.uid() and lower(u.email)=i.email and u.email_confirmed_at is not null;
$$;
create function public.planner_accept_invite(p_invitation uuid) returns uuid
language plpgsql security definer set search_path=pg_catalog,public as $$
declare target uuid;
begin
 select i.workspace_id into target from public.planner_invitations i join auth.users u
 on u.id=auth.uid() and lower(u.email)=i.email and u.email_confirmed_at is not null
 where i.id=p_invitation for update of i;
 if target is null then raise exception 'Invitation not found or email not confirmed'; end if;
 insert into public.planner_members values(target,auth.uid()) on conflict do nothing;
 delete from public.planner_invitations where id=p_invitation;
 return target;
end; $$;
create function public.planner_remove_member(p_workspace uuid,p_user uuid) returns void
language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 if not exists(select 1 from public.planner_workspaces where id=p_workspace and owner_id=auth.uid() and kind='team') then raise exception 'Only the owner can remove members'; end if;
 delete from public.planner_members where workspace_id=p_workspace and user_id=p_user;
end; $$;
create function public.planner_cancel_invite(p_invitation uuid) returns void
language plpgsql security definer set search_path=pg_catalog,public as $$
begin
 delete from public.planner_invitations i using public.planner_workspaces w
 where i.id=p_invitation and w.id=i.workspace_id and w.owner_id=auth.uid();
end; $$;
create function public.planner_save(p_workspace uuid,p_payload jsonb,p_expected_revision bigint) returns bigint
language plpgsql security definer set search_path=pg_catalog,public as $$
declare result bigint;
begin
 if not public.planner_can_access(p_workspace) then raise exception 'Workspace access denied'; end if;
 if jsonb_typeof(p_payload) <> 'object' or p_payload->>'version' is distinct from '1'
 or jsonb_typeof(p_payload->'clients') is distinct from 'array' or jsonb_array_length(p_payload->'clients')=0
 or jsonb_typeof(p_payload->'items') is distinct from 'array'
 or jsonb_typeof(p_payload->'ideas') is distinct from 'array'
 or jsonb_typeof(p_payload->'shoots') is distinct from 'object' then raise exception 'Invalid planner data'; end if;
 if octet_length(p_payload::text)>20000000 then raise exception 'Workspace is larger than 20 MB. Reduce uploaded images before syncing.'; end if;
 if p_expected_revision=0 then
 insert into public.planner_documents(workspace_id,payload,updated_by) values(p_workspace,p_payload,auth.uid())
 on conflict do nothing returning revision into result;
 else
 update public.planner_documents set payload=p_payload,revision=revision+1,updated_at=now(),updated_by=auth.uid()
 where workspace_id=p_workspace and revision=p_expected_revision returning revision into result;
 end if;
 if result is null then raise exception 'PLANNER_CONFLICT: Another device changed this workspace. Reload before editing.' using errcode='40001'; end if;
 return result;
end; $$;

revoke all on public.planner_workspaces,public.planner_members,public.planner_invitations,public.planner_documents from anon,authenticated;
grant select on public.planner_workspaces,public.planner_members,public.planner_invitations,public.planner_documents to authenticated;
revoke all on function public.planner_can_access(uuid),public.planner_personal_workspace(),public.planner_create_team(text),public.planner_invite(uuid,text),public.planner_pending_invites(),public.planner_accept_invite(uuid),public.planner_remove_member(uuid,uuid),public.planner_cancel_invite(uuid),public.planner_save(uuid,jsonb,bigint) from public,anon;
grant execute on function public.planner_can_access(uuid),public.planner_personal_workspace(),public.planner_create_team(text),public.planner_invite(uuid,text),public.planner_pending_invites(),public.planner_accept_invite(uuid),public.planner_remove_member(uuid,uuid),public.planner_cancel_invite(uuid),public.planner_save(uuid,jsonb,bigint) to authenticated;
commit;
