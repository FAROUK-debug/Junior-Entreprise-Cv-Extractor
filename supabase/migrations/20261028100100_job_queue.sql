-- The queue functions the Python worker calls (S1-24), through supabase-py:
--   supabase.rpc("claim_next_job").execute().data   → [] or [job]
--   supabase.rpc("requeue_stuck_jobs").execute()     → at start-up
-- Only the service role may run them: the browser never touches the queue.

-- Hands the worker the oldest job that may run now, and marks it processing.
-- FOR UPDATE SKIP LOCKED: if two workers ask at the same moment, they get different jobs.
create function public.claim_next_job() returns setof public.extraction_jobs
language sql set search_path = '' as $$
  update public.extraction_jobs j
     set status = 'processing', attempts = j.attempts + 1, started_at = now()
   where j.id = (select id from public.extraction_jobs
                  where status = 'queued' and run_after <= now()
                  order by created_at
                  limit 1
                  for update skip locked)
  returning j.*
$$;

-- At start-up: jobs left in "processing" by a crash go back in line, unless they already had
-- max_attempts tries; those fail, so a CV that crashes the worker can't loop forever.
create function public.requeue_stuck_jobs(max_attempts int default 3) returns int
language plpgsql set search_path = '' as $$
declare handled int;
begin
  update public.extraction_jobs
     set status        = case when attempts >= max_attempts then 'failed' else 'queued' end,
         error_message = case when attempts >= max_attempts
                              then 'We couldn''t read this file. Try a PDF export of your CV.'
                              else error_message end,
         finished_at   = case when attempts >= max_attempts then now() else null end
   where status = 'processing';
  get diagnostics handled = row_count;
  return handled;
end $$;

-- Supabase lets every role run new functions by default; take that back.
revoke execute on function public.claim_next_job() from public, anon, authenticated;
revoke execute on function public.requeue_stuck_jobs(int) from public, anon, authenticated;
grant execute on function public.claim_next_job() to service_role;
grant execute on function public.requeue_stuck_jobs(int) to service_role;
