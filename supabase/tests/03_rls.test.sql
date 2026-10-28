-- S1-17: who can see and change what. Each test logs in as a role, the way the browser does,
-- and checks what the database lets through. The table of rules is in docs/DATABASE.md.
begin;
create extension if not exists pgtap with schema extensions;
select plan(41);

-- ── the cast ─────────────────────────────────────────────────────────────
-- a: candidate with a draft · b: approved · c: approved but hidden
-- x: active company · y: disabled company · z: admin
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'c@test.local'),
  ('00000000-0000-0000-0000-0000000000aa', 'x@test.local'),
  ('00000000-0000-0000-0000-0000000000bb', 'y@test.local'),
  ('00000000-0000-0000-0000-0000000000ff', 'z@test.local');
insert into public.profiles (user_id, status, hidden, looking_for, data) values
  ('00000000-0000-0000-0000-00000000000a', 'draft',    false, 'pfe', '{"basics": {"name": "A"}}'),
  ('00000000-0000-0000-0000-00000000000b', 'approved', false, 'job', '{"basics": {"name": "B"}}'),
  ('00000000-0000-0000-0000-00000000000c', 'approved', true,  'job', '{"basics": {"name": "C"}}');
insert into public.profile_drafts (user_id, data) values
  ('00000000-0000-0000-0000-00000000000a', '{"basics": {"name": "A draft"}}'),
  ('00000000-0000-0000-0000-00000000000b', '{"basics": {"name": "B new upload"}}');
insert into public.extraction_jobs (user_id, kind) values
  ('00000000-0000-0000-0000-00000000000a', 'extract'),
  ('00000000-0000-0000-0000-00000000000b', 'embed');
insert into public.companies (user_id, name, disabled) values
  ('00000000-0000-0000-0000-0000000000aa', 'X Corp', false),
  ('00000000-0000-0000-0000-0000000000bb', 'Y Corp', true);

-- Log in as someone: the same JWT claims Supabase Auth puts in a real session.
create function pg_temp.login(uid uuid, app_role text, user_role text default null) returns void
language sql as $$
  select set_config('request.jwt.claims', json_build_object(
    'sub', uid, 'role', 'authenticated',
    'app_metadata', json_build_object('role', app_role),
    'user_metadata', json_build_object('role', user_role))::text, true);
  set local role authenticated;
$$;

-- ── logged out: nothing at all ───────────────────────────────────────────
set local role anon;
select throws_ok('select * from public.profiles', '42501', null, 'logged out: cannot read profiles');
select throws_ok('select * from public.profile_drafts', '42501', null, 'logged out: cannot read drafts');
select throws_ok('select * from public.companies', '42501', null, 'logged out: cannot read companies');
select throws_ok('select * from public.extraction_jobs', '42501', null, 'logged out: cannot read jobs');
reset role;

-- ── an active company ────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-0000000000aa', 'company');
select results_eq('select data->''basics''->>''name'' from public.profiles',
                  $$values ('B')$$, 'company sees only approved, visible profiles (not the draft A, not the hidden C)');
select is((select count(*)::int from public.profile_drafts), 0, 'company sees no drafts, not even of an approved profile');
select is((select count(*)::int from public.extraction_jobs), 0, 'company sees no jobs');
select results_eq('select name from public.companies', $$values ('X Corp')$$, 'company sees only its own company row');
select lives_ok($$update public.companies set description = 'We build things'
                  where user_id = '00000000-0000-0000-0000-0000000000aa'$$, 'company edits its own description');
select throws_ok($$update public.companies set disabled = false
                   where user_id = '00000000-0000-0000-0000-0000000000aa'$$, '42501', null,
                 'company cannot change its own disabled flag');
update public.companies set name = 'hacked' where user_id = '00000000-0000-0000-0000-0000000000bb';
update public.profiles set hidden = true where user_id = '00000000-0000-0000-0000-00000000000b';
select throws_ok($$insert into public.companies (user_id, name)
                   values ('00000000-0000-0000-0000-0000000000aa', 'second')$$, '42501', null,
                 'company cannot create companies');
reset role;
select is((select name from public.companies where user_id = '00000000-0000-0000-0000-0000000000bb'),
          'Y Corp', 'company cannot rename another company');
select is((select hidden from public.profiles where user_id = '00000000-0000-0000-0000-00000000000b'),
          false, 'company cannot hide a candidate''s profile');

-- ── a disabled company ───────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-0000000000bb', 'company');
select is((select count(*)::int from public.profiles), 0, 'a disabled company sees no profiles');
reset role;

-- ── a company role without a company row (e.g. deleted by the admin) ─────
select pg_temp.login('00000000-0000-0000-0000-0000000000ee', 'company');
select is((select count(*)::int from public.profiles), 0, 'company role without a company row sees no profiles');
reset role;

-- ── a candidate ──────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'candidate');
select results_eq('select data->''basics''->>''name'' from public.profiles', $$values ('A')$$,
                  'candidate sees only their own profile, even a draft');
select results_eq('select data->''basics''->>''name'' from public.profile_drafts', $$values ('A draft')$$,
                  'candidate sees only their own draft');
select is((select count(*)::int from public.extraction_jobs), 1, 'candidate sees only their own jobs');
select is((select count(*)::int from public.companies), 0, 'candidate sees no companies');
select lives_ok($$update public.profiles set hidden = true, looking_for = 'internship'
                  where user_id = '00000000-0000-0000-0000-00000000000a'$$,
                'candidate can hide their profile and change what they look for');
select lives_ok($$update public.profile_drafts set data = '{"basics": {"name": "A fixed"}}'
                  where user_id = '00000000-0000-0000-0000-00000000000a'$$,
                'candidate can edit their own draft (the review form)');
select throws_ok($$update public.profiles set status = 'approved'
                   where user_id = '00000000-0000-0000-0000-00000000000a'$$, '42501', null,
                 'candidate cannot approve directly (approval goes through the server, which validates)');
select throws_ok($$update public.profiles set data = '{}'
                   where user_id = '00000000-0000-0000-0000-00000000000a'$$, '42501', null,
                 'candidate cannot change live data directly (only by approving a draft)');
select throws_ok($$update public.profiles set public_id = '1'
                   where user_id = '00000000-0000-0000-0000-00000000000a'$$, '42501', null,
                 'candidate cannot choose their public_id');
select throws_ok($$update public.profiles set embedding = null
                   where user_id = '00000000-0000-0000-0000-00000000000a'$$, '42501', null,
                 'candidate cannot touch the embedding');
select throws_ok($$insert into public.extraction_jobs (user_id, kind)
                   values ('00000000-0000-0000-0000-00000000000a', 'extract')$$, '42501', null,
                 'candidate cannot create jobs (the upload API does, after its checks)');
select throws_ok($$insert into public.profiles (user_id) values ('00000000-0000-0000-0000-00000000000a')$$,
                 '42501', null, 'candidate cannot create profiles');
select throws_ok($$delete from public.profiles where user_id = '00000000-0000-0000-0000-00000000000a'$$,
                 '42501', null, 'candidate cannot delete rows directly (account deletion goes through the server)');
update public.profiles set hidden = true where user_id = '00000000-0000-0000-0000-00000000000b';
update public.profile_drafts set data = '{}' where user_id = '00000000-0000-0000-0000-00000000000b';
reset role;
select is((select hidden from public.profiles where user_id = '00000000-0000-0000-0000-00000000000b'),
          false, 'candidate cannot hide someone else''s profile');
select is((select data->'basics'->>'name' from public.profile_drafts where user_id = '00000000-0000-0000-0000-00000000000b'),
          'B new upload', 'candidate cannot edit someone else''s draft');
select is((select hidden from public.profiles where user_id = '00000000-0000-0000-0000-00000000000a'),
          true, 'the allowed change really happened');

-- ── a candidate who wrote "company" in the metadata they control ─────────
-- user_metadata can be edited by the user; only app_metadata (server-set) counts.
select pg_temp.login('00000000-0000-0000-0000-00000000000a', 'candidate', 'company');
select is((select count(*)::int from public.profiles), 1, 'user_metadata role is ignored: still only their own profile');
reset role;

-- ── the admin ────────────────────────────────────────────────────────────
select pg_temp.login('00000000-0000-0000-0000-0000000000ff', 'admin');
select is((select count(*)::int from public.profiles), 3, 'admin sees every profile');
select is((select count(*)::int from public.profile_drafts), 2, 'admin sees every draft');
select is((select count(*)::int from public.companies), 2, 'admin sees every company');
select is((select count(*)::int from public.extraction_jobs), 2, 'admin sees every job');
select throws_ok($$update public.companies set disabled = true
                   where user_id = '00000000-0000-0000-0000-0000000000aa'$$, '42501', null,
                 'admin writes go through server code (service role), not the browser');
reset role;

-- ── the server (service role key) can do its job ─────────────────────────
set local role service_role;
select is((select count(*)::int from public.profiles), 3, 'server reads every profile');
select lives_ok($$update public.profiles set status = 'approved'
                  where user_id = '00000000-0000-0000-0000-00000000000a'$$, 'server can approve');
select lives_ok($$insert into public.extraction_jobs (user_id, kind)
                  values ('00000000-0000-0000-0000-00000000000a', 'embed')$$, 'server can queue jobs');
reset role;

-- ── every table in public has RLS on (a new table without it fails here) ─
select is((select count(*)::int from pg_tables where schemaname = 'public' and not rowsecurity), 0,
          'RLS is on for every table in the public schema');

select * from finish();
rollback;
