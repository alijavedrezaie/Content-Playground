# Account and cloud storage setup

The planner uses Supabase Auth for email/password accounts and Postgres row-level security for private and team workspaces. It continues to run on GitHub Pages. Account features stay inactive until both public settings in `src/cloud-config.js` are configured; existing browser plans remain available in local mode meanwhile.

## Preserve the October plan

In the browser and website address where your October work is visible, click Backup. Keep the JSON file. Local storage belongs to that exact website and browser; opening the app at a different path or device does not move it. Do not clear browser storage. The upgrade does not delete or overwrite the old `content-playground-v1` data.

## Create the Supabase project

1. Go to https://supabase.com/dashboard and create an account and project. Choose your region and database password yourself. Keep the database password private.
2. Open the project's SQL Editor. Run all of `supabase/schema.sql` once.
3. Run `supabase/verify-access.sql` in SQL Editor. It creates synthetic users inside a transaction and rolls everything back. It checks private isolation, invitation acceptance, team access, stale revisions, removal and anonymous denial. Do not activate the app if it raises a FAIL error.
4. In Authentication → URL Configuration, set Site URL and allowed Redirect URLs to the exact planner address, including `/src/` if used. For the current site: `https://alijavedrezaie.github.io/Content-Playground/src/`. If you later serve the root, add its exact URL too.
5. Keep email confirmation enabled. Configure an email sender under Authentication before inviting a real team; Supabase's default sender has restrictions and is intended for testing. Use your own SMTP provider for production confirmation and password-reset emails.
6. Find Project URL and the publishable key in the project's Connect/API settings. Enter these in `src/cloud-config.js`. Only the publishable (`sb_publishable_...`) key, or a legacy `anon` key, belongs in a browser. Never put a secret or service_role key in source control.
7. Run `python3 scripts/build.py`. Commit and push. GitHub Pages serving `/src/` loads the new scripts directly; `dist/` and the standalone download are also rebuilt.

## Move October into your account

1. Open the same planner address and browser that held October. Create your account, confirm the email and log in.
2. A notice offers to import existing browser plans into **My private plans**. Download the original backup if you have not already.
3. Click Import my existing plans. Client IDs and content IDs are remapped to avoid overwriting cloud content. The October month, shots, dates, images and notes are copied. The browser copy remains untouched.
4. Wait for Saved to your account. Select October and verify your actual entries.
5. Log in on a second device and verify October there before relying on cloud storage.
6. If the import notice is absent because you are on another browser or address, log into your private workspace, use Restore backup and select the JSON backup from the original browser. Restore replaces the CURRENT workspace, so use it only in the empty private workspace or back up current cloud plans first.

## Team use

Each new account gets its own private workspace. It does not inherit the original user's October plans.

Open Team & account, create a team workspace, then invite a teammate's exact email. Share the website URL with them yourself. They sign up, confirm their email, open Team & account and accept the invitation. This version shows invitations inside the app; it does not send invitation emails automatically.

Workspace owners manage invitations and member removal. Invited members can edit all plans within that team workspace, but cannot see anyone's private workspace or invite more people. Select the workspace in the top bar before editing. To move a private plan into a team, use an export/backup deliberately; there is no automatic sharing of private data.

## Sync behavior and verification limits

Changes are cached per account/workspace and uploaded after a short delay. Focus/30-second polling loads newer cloud changes while the editor is closed. This is not live simultaneous co-editing. The database checks a revision on every save; conflicting changes require downloading the unsynced copy and loading the latest cloud version rather than silently overwriting a teammate.

Local data and mocked synchronization tests run with `node tests/cloud-data.test.cjs`. End-to-end sign-up, email delivery, two-account database isolation and two-device migration must be verified against the configured Supabase project before production use. The local tests alone do not verify deployed permissions or email delivery.

The legacy browser data is not protected by the new login until it is imported and you deliberately remove that old browser copy after verifying backups. Other account caches are not shown through the app, but shared computers should use separate OS/browser profiles. Accounts and plan data live in your Supabase project and are subject to its storage and service limits.
