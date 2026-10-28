-- S1-16: the tables. Every column is explained in plain words in docs/DATABASE.md.
-- Access rules (RLS) come in the next migration (S1-17); until then nothing here is reachable
-- from the browser, because Supabase turns RLS on and we add no policy yet (see the end of this file).

create extension if not exists vector with schema extensions;    -- pgvector: embeddings
create extension if not exists pgcrypto with schema extensions;  -- gen_random_bytes for public_id

-- Keeps updated_at correct on every change, so nobody has to remember to set it.
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- A long random token for QR links: 16 random bytes → 22 URL-safe characters.
-- Never a number: nobody can walk through profiles by changing the URL (design §2.4).
create function public.new_public_id() returns text
language sql volatile set search_path = '' as $$
  select rtrim(translate(encode(extensions.gen_random_bytes(16), 'base64'), '+/', '-_'), '=')
$$;

-- ── profiles: what companies see, once approved ─────────────────────────
-- The row is created by the upload API (status draft, empty data). Its data changes only when
-- the candidate approves a draft, so the live profile is always one the candidate checked.
create table public.profiles (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  public_id    text not null unique default public.new_public_id(),
  status       text not null default 'draft' check (status in ('draft', 'approved')),
  hidden       boolean not null default false,
  looking_for  text check (looking_for in ('pfe', 'internship', 'job')),
  data         jsonb not null default '{}',     -- the profile, shaped by worker/cv_worker/schema.py
  search_tsv   tsvector generated always as (jsonb_to_tsvector('simple', data, '["string"]')) stored,
  embedding    extensions.vector(1024),         -- mistral-embed only (design §3)
  approved_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index profiles_search_tsv_idx on public.profiles using gin (search_tsv);
create index profiles_embedding_idx on public.profiles using hnsw (embedding extensions.vector_cosine_ops);
create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- ── profile_drafts: what the AI extracted, before the candidate approves it ─
-- A separate table, not a column on profiles: RLS works per row, so a company allowed to read
-- an approved profile row would also read a draft column on it (unreviewed data).
create table public.profile_drafts (
  user_id     uuid primary key references auth.users (id) on delete cascade,
  data        jsonb not null,
  provider    text check (provider in ('mistral', 'gemini')),   -- which AI produced it
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create trigger profile_drafts_updated_at before update on public.profile_drafts
  for each row execute function public.set_updated_at();

-- ── companies: one row per company login, created by the admin ──────────
create table public.companies (
  user_id      uuid primary key references auth.users (id) on delete cascade,
  name         text not null,
  sector       text,
  description  text,
  website      text,
  logo_url     text,
  disabled     boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create trigger companies_updated_at before update on public.companies
  for each row execute function public.set_updated_at();

-- ── extraction_jobs: the queue between the web app and the Python worker ─
create table public.extraction_jobs (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users (id) on delete cascade,
  kind           text not null check (kind in ('extract', 'embed')),
  status         text not null default 'queued' check (status in ('queued', 'processing', 'done', 'failed')),
  attempts       int not null default 0,
  error_message  text,         -- shown to the candidate, so plain words, never a stack trace
  file_path      text,         -- the temporary upload in uploads-tmp; extract jobs only
  run_after      timestamptz not null default now(),   -- pushed later to back off after a 429
  started_at     timestamptz,
  finished_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index extraction_jobs_queue_idx on public.extraction_jobs (run_after, created_at)
  where status = 'queued';
create index extraction_jobs_user_idx on public.extraction_jobs (user_id);
create trigger extraction_jobs_updated_at before update on public.extraction_jobs
  for each row execute function public.set_updated_at();

-- RLS on from the first minute: with no policy, the browser roles see nothing.
alter table public.profiles enable row level security;
alter table public.profile_drafts enable row level security;
alter table public.companies enable row level security;
alter table public.extraction_jobs enable row level security;
