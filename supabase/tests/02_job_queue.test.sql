-- S1-16 / S1-24: the queue functions the Python worker calls.
begin;
create extension if not exists pgtap with schema extensions;
select plan(13);

insert into auth.users (id, email) values ('00000000-0000-0000-0000-00000000000a', 'cand.a@test.local');

-- Three jobs: an old one, a newer one, and one that must wait (backing off after a 429)
insert into public.extraction_jobs (id, user_id, kind, created_at, run_after) values
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-00000000000a', 'extract', now() - interval '2 min', now()),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-00000000000a', 'embed',   now() - interval '1 min', now()),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-00000000000a', 'extract', now() - interval '3 min', now() + interval '1 hour');

create temp table claimed as select * from public.claim_next_job();
select is((select id from claimed), '10000000-0000-0000-0000-000000000001',
          'claims the oldest job that is allowed to run (not the one waiting until later)');
select is((select status from public.extraction_jobs where id = '10000000-0000-0000-0000-000000000001'),
          'processing', 'the claimed job is marked processing');
select is((select attempts from public.extraction_jobs where id = '10000000-0000-0000-0000-000000000001'),
          1, 'claiming counts one attempt');
select ok((select started_at is not null from public.extraction_jobs where id = '10000000-0000-0000-0000-000000000001'),
          'claiming records when the job started');

select is((select id from public.claim_next_job()), '10000000-0000-0000-0000-000000000002',
          'the next claim gets the next job, never the same one twice');
select is((select count(*)::int from public.claim_next_job()), 0,
          'nothing left that may run → an empty result, not an error');

-- A crash leaves jobs in "processing". At start-up the worker puts them back in line,
-- unless they already used their 3 attempts: then they fail with a message for the candidate.
update public.extraction_jobs set attempts = 3 where id = '10000000-0000-0000-0000-000000000002';
select is(public.requeue_stuck_jobs(), 2, 'returns how many stuck jobs it handled');
select is((select status from public.extraction_jobs where id = '10000000-0000-0000-0000-000000000001'),
          'queued', 'a stuck job with attempts left goes back to queued');
select is((select status from public.extraction_jobs where id = '10000000-0000-0000-0000-000000000002'),
          'failed', 'a stuck job with no attempts left fails');
select ok((select length(error_message) > 0 from public.extraction_jobs where id = '10000000-0000-0000-0000-000000000002'),
          'a failed job always carries a message (nobody waits on a silent spinner)');

-- Only the server (service role) may run the queue. A logged-in browser user may not.
set local role authenticated;
select throws_ok('select * from public.claim_next_job()', '42501', null,
                 'a logged-in user cannot claim jobs');
select throws_ok('select public.requeue_stuck_jobs()', '42501', null,
                 'a logged-in user cannot requeue jobs');
reset role;
set local role anon;
select throws_ok('select * from public.claim_next_job()', '42501', null,
                 'a logged-out visitor cannot claim jobs');
reset role;

select * from finish();
rollback;
