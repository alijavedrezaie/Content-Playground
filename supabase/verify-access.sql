-- Run AFTER schema.sql in SQL Editor. Uses synthetic users and rolls everything back.
-- Success ends in ROLLBACK with no exceptions. No real accounts or plans are changed.
begin;
create temporary table planner_test_ids(label text primary key,id uuid);
grant all on planner_test_ids to authenticated;
insert into auth.users(id,email,email_confirmed_at) values
 ('10000000-0000-4000-8000-000000000001','planner-test-a@example.invalid',now()),
 ('10000000-0000-4000-8000-000000000002','planner-test-b@example.invalid',now()),
 ('10000000-0000-4000-8000-000000000003','planner-test-c@example.invalid',now());
set local role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","email":"planner-test-a@example.invalid"}',true);
insert into planner_test_ids values('private_a',public.planner_personal_workspace()),('team_a',public.planner_create_team('Test team'));
select public.planner_save((select id from planner_test_ids where label='private_a'),'{"version":1,"clients":[{"id":"test"}],"items":[],"ideas":[],"shoots":{}}',0);
select public.planner_save((select id from planner_test_ids where label='team_a'),'{"version":1,"clients":[{"id":"test"}],"items":[],"ideas":[],"shoots":{}}',0);
select public.planner_invite((select id from planner_test_ids where label='team_a'),'planner-test-b@example.invalid');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000002","email":"planner-test-b@example.invalid"}',true);
do $$ begin
 if exists(select 1 from public.planner_documents where workspace_id=(select id from planner_test_ids where label='private_a')) then raise exception 'FAIL: B can read A private plan'; end if;
 if public.planner_can_access((select id from planner_test_ids where label='team_a')) then raise exception 'FAIL: Invitation alone granted access'; end if;
 begin
 perform public.planner_save((select id from planner_test_ids where label='private_a'),'{"version":1,"clients":[{}],"items":[],"ideas":[],"shoots":{}}',1);
 raise exception 'FAIL: B saved A private plan';
 exception when raise_exception then if SQLERRM like 'FAIL:%' then raise; end if; end;
end $$;
select public.planner_accept_invite(id) from public.planner_pending_invites();
do $$ begin
 if not public.planner_can_access((select id from planner_test_ids where label='team_a')) then raise exception 'FAIL: Accepted member lacks access'; end if;
 if exists(select 1 from public.planner_documents where workspace_id=(select id from planner_test_ids where label='private_a')) then raise exception 'FAIL: Team membership exposed private plans'; end if;
end $$;
select public.planner_save((select id from planner_test_ids where label='team_a'),'{"version":1,"clients":[{}],"items":[],"ideas":[],"shoots":{}}',1);
do $$ begin
 begin
 perform public.planner_save((select id from planner_test_ids where label='team_a'),'{"version":1,"clients":[{}],"items":[],"ideas":[],"shoots":{}}',1);
 raise exception 'FAIL: Stale revision overwrote latest plan';
 exception when serialization_failure then null; end;
 begin
 perform public.planner_invite((select id from planner_test_ids where label='team_a'),'planner-test-c@example.invalid');
 raise exception 'FAIL: Non-owner invited a member';
 exception when raise_exception then if SQLERRM like 'FAIL:%' then raise; end if; end;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","email":"planner-test-c@example.invalid"}',true);
do $$ begin
 if exists(select 1 from public.planner_documents) then raise exception 'FAIL: Uninvited user can read plans'; end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","email":"planner-test-a@example.invalid"}',true);
select public.planner_remove_member((select id from planner_test_ids where label='team_a'),'10000000-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
do $$ begin
 if public.planner_can_access((select id from planner_test_ids where label='team_a')) then raise exception 'FAIL: Removed member retains access'; end if;
end $$;
reset role;
set local role anon;
do $$ begin
 begin
 perform public.planner_personal_workspace();
 raise exception 'FAIL: Anonymous user can create a private workspace';
 exception when insufficient_privilege then null; end;
 begin
 perform 1 from public.planner_documents;
 raise exception 'FAIL: Anonymous role can read documents';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
rollback;
