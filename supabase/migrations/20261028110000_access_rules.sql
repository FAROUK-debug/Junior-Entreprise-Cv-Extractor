-- S1-17: who can see and change what. Two layers, because each one alone has a hole:
--   1. Table and column permissions (GRANT): which columns a browser role may read or change at all.
--      RLS can't stop a candidate from setting status = 'approved' on their own row; this can.
--   2. Row-level security policies: which rows each person sees.
-- The server uses the service role key, which skips both layers; that's why it never reaches the browser.
-- Tests: supabase/tests/03_rls.test.sql. Rules in plain words: docs/DATABASE.md.

-- The role (candidate | company | admin) comes from app_metadata, which only the server can set.
-- Never from user_metadata: users can edit their own user_metadata.
create function public.jwt_role() returns text
language sql stable set search_path = '' as $$
  select coalesce(auth.jwt() -> 'app_metadata' ->> 'role', '')
$$;

-- A company counts only if its company row exists and isn't disabled by the admin.
-- security definer: it reads companies itself, without depending on the caller's own policies.
create function public.is_active_company() returns boolean
language sql stable security definer set search_path = '' as $$
  select public.jwt_role() = 'company'
     and exists (select 1 from public.companies c where c.user_id = auth.uid() and not c.disabled)
$$;

-- ── layer 1: permissions ─────────────────────────────────────────────────
-- Supabase gives anon and authenticated every right on new tables by default. Start from zero.
revoke all on public.profiles, public.profile_drafts, public.companies, public.extraction_jobs
  from anon, authenticated;

-- Logged-in users may read (layer 2 decides which rows) ...
grant select on public.profiles, public.profile_drafts, public.companies, public.extraction_jobs
  to authenticated;
-- ... and change only these columns. Everything else goes through server code.
grant update (looking_for, hidden) on public.profiles to authenticated;          -- candidate
grant update (data) on public.profile_drafts to authenticated;                   -- candidate (review form)
grant update (name, sector, description, website, logo_url) on public.companies to authenticated;  -- company

-- ── layer 2: rows ────────────────────────────────────────────────────────
-- profiles
create policy "candidates read their own profile" on public.profiles
  for select to authenticated using (user_id = auth.uid());
create policy "active companies read approved, visible profiles" on public.profiles
  for select to authenticated using (status = 'approved' and not hidden and public.is_active_company());
create policy "admin reads every profile" on public.profiles
  for select to authenticated using (public.jwt_role() = 'admin');
create policy "candidates change their own profile" on public.profiles
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- profile_drafts: never companies
create policy "candidates read their own draft" on public.profile_drafts
  for select to authenticated using (user_id = auth.uid());
create policy "admin reads every draft" on public.profile_drafts
  for select to authenticated using (public.jwt_role() = 'admin');
create policy "candidates edit their own draft" on public.profile_drafts
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- companies
create policy "companies read their own row" on public.companies
  for select to authenticated using (user_id = auth.uid());
create policy "admin reads every company" on public.companies
  for select to authenticated using (public.jwt_role() = 'admin');
create policy "companies edit their own row" on public.companies
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- extraction_jobs: read-only for the browser (the "Processing your CV" page)
create policy "candidates read their own jobs" on public.extraction_jobs
  for select to authenticated using (user_id = auth.uid());
create policy "admin reads every job" on public.extraction_jobs
  for select to authenticated using (public.jwt_role() = 'admin');
