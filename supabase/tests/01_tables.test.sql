-- S1-16: what the tables must do. Run with `supabase test db`.
-- Everything runs in a transaction that is rolled back, so tests leave no data behind.
begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

-- Two fake users (auth.users is Supabase's own table of accounts)
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'cand.a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'cand.b@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'company.c@test.local');

-- ── the tables exist ─────────────────────────────────────────────────────
select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'profile_drafts', 'profile_drafts exists');
select has_table('public', 'companies', 'companies exists');
select has_table('public', 'extraction_jobs', 'extraction_jobs exists');

-- ── profiles ─────────────────────────────────────────────────────────────
insert into public.profiles (user_id, looking_for, data) values
  ('00000000-0000-0000-0000-00000000000a', 'pfe',
   '{"basics": {"name": "Amira Ben Salah", "headline": "Computer vision student"},
     "skills": ["PyTorch", "OpenCV"]}'),
  ('00000000-0000-0000-0000-00000000000b', 'job', '{}');

select is((select status from public.profiles where user_id = '00000000-0000-0000-0000-00000000000a'),
          'draft', 'a new profile starts as draft');
select ok((select public_id ~ '^[A-Za-z0-9_-]{22}$' from public.profiles
           where user_id = '00000000-0000-0000-0000-00000000000a'),
          'public_id is a 22-character URL-safe random token');
select isnt((select public_id from public.profiles where user_id = '00000000-0000-0000-0000-00000000000a'),
            (select public_id from public.profiles where user_id = '00000000-0000-0000-0000-00000000000b'),
            'two profiles get different public_ids');
select throws_ok($$update public.profiles set status = 'published'
                   where user_id = '00000000-0000-0000-0000-00000000000a'$$,
                 '23514', null, 'status only accepts draft | approved');
select throws_ok($$update public.profiles set looking_for = 'freelance'
                   where user_id = '00000000-0000-0000-0000-00000000000a'$$,
                 '23514', null, 'looking_for only accepts pfe | internship | job');
select throws_ok($$insert into public.profiles (user_id, looking_for)
                   values ('00000000-0000-0000-0000-00000000000a', 'job')$$,
                 '23505', null, 'one profile per account');
select throws_ok($$update public.profiles set embedding = '[1,2,3]'
                   where user_id = '00000000-0000-0000-0000-00000000000a'$$,
                 '22000', null, 'embedding must have exactly 1024 numbers (mistral-embed)');
select lives_ok($$update public.profiles set embedding = array_fill(0.1, array[1024])::extensions.vector
                  where user_id = '00000000-0000-0000-0000-00000000000a'$$,
                'a 1024-number embedding is accepted');
select ok((select search_tsv @@ to_tsquery('simple', 'pytorch') from public.profiles
           where user_id = '00000000-0000-0000-0000-00000000000a'),
          'full-text search finds a skill inside the profile data, ignoring case');
select ok(not (select search_tsv @@ to_tsquery('simple', 'django') from public.profiles
               where user_id = '00000000-0000-0000-0000-00000000000a'),
          'full-text search does not find a word that is not there');

update public.profiles set updated_at = now() - interval '1 day'
  where user_id = '00000000-0000-0000-0000-00000000000b';
update public.profiles set hidden = true where user_id = '00000000-0000-0000-0000-00000000000b';
select ok((select updated_at > now() - interval '1 minute' from public.profiles
           where user_id = '00000000-0000-0000-0000-00000000000b'),
          'updated_at moves forward on every change');

-- ── companies ────────────────────────────────────────────────────────────
insert into public.companies (user_id, name) values ('00000000-0000-0000-0000-00000000000c', 'Acme');
select is((select disabled from public.companies where name = 'Acme'), false,
          'a new company is enabled');

-- ── extraction_jobs ──────────────────────────────────────────────────────
select throws_ok($$insert into public.extraction_jobs (user_id, kind)
                   values ('00000000-0000-0000-0000-00000000000a', 'translate')$$,
                 '23514', null, 'kind only accepts extract | embed');
select is((select count(*)::int from public.extraction_jobs), 0, 'no job yet');

-- ── deleting an account deletes everything about it ──────────────────────
insert into public.profile_drafts (user_id, data) values ('00000000-0000-0000-0000-00000000000a', '{}');
insert into public.extraction_jobs (user_id, kind, file_path)
  values ('00000000-0000-0000-0000-00000000000a', 'extract', 'a/cv.pdf');
delete from auth.users where id = '00000000-0000-0000-0000-00000000000a';
select is((select count(*)::int from public.profiles where user_id = '00000000-0000-0000-0000-00000000000a'),
          0, 'account deleted → profile deleted');
select is((select count(*)::int from public.profile_drafts where user_id = '00000000-0000-0000-0000-00000000000a'),
          0, 'account deleted → draft deleted');
select is((select count(*)::int from public.extraction_jobs where user_id = '00000000-0000-0000-0000-00000000000a'),
          0, 'account deleted → jobs deleted');
delete from auth.users where id = '00000000-0000-0000-0000-00000000000c';
select is((select count(*)::int from public.companies), 0, 'account deleted → company deleted');

-- ── search indexes exist (the HNSW one makes vector search fast) ─────────
select ok(exists(select 1 from pg_indexes where tablename = 'profiles' and indexdef ilike '%gin%search_tsv%'),
          'GIN index on search_tsv');
select ok(exists(select 1 from pg_indexes where tablename = 'profiles' and indexdef ilike '%hnsw%embedding%'),
          'HNSW index on embedding');

select * from finish();
rollback;
