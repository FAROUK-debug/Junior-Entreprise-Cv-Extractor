# The database

Everything lives in one Supabase Postgres database. The tables are created by the SQL files in
`supabase/migrations/`, applied in order. Nobody creates or changes a table by clicking in the
Supabase dashboard: a change is a new migration file, reviewed in a PR like any code.

## The idea in one picture

```
 candidate uploads ──► extraction_jobs (queued) ──► Python worker ──► profile_drafts
                                                                          │ candidate checks and approves
                                                                          ▼
                                    companies ──── read approved ────► profiles
```

- **`profiles`** is what companies see. It only changes when the candidate approves.
- **`profile_drafts`** is what the AI extracted, waiting for the candidate to check it. Companies never see it.
- **`extraction_jobs`** is the queue between the web app and the worker.
- **`companies`** is one row per company login.

Every table has **row-level security (RLS)** switched on. That means the database itself decides
who can read which row, so a bug in a page cannot leak data. The rules are in S1-17's migration.

Every table is linked to the user's account (`auth.users`, Supabase's own table) with
`on delete cascade`: **deleting an account deletes every row about that person**, in every table.

## profiles

| Column | What it holds |
|---|---|
| `user_id` | The candidate's account. One profile per account |
| `public_id` | A random 22-character token used in the QR code link (`/p/<public_id>`). Never a number, so nobody can guess other profiles' links |
| `status` | `draft` until the candidate approves for the first time, then `approved`. Companies only see `approved` |
| `hidden` | The candidate's "hide my profile" switch. Hidden profiles are invisible to companies but not deleted |
| `looking_for` | `pfe`, `internship` or `job`. Chosen by the candidate at upload, never by the AI |
| `data` | The whole profile (name, education, skills…) as JSON, shaped by `worker/cv_worker/schema.py` |
| `search_tsv` | Filled automatically from `data`: every word in the profile, ready for fast word search ("PyTorch", "ENIT"). Never written by hand |
| `embedding` | 1,024 numbers from `mistral-embed` that represent the profile's meaning, for "search by meaning". Empty until the worker computes it |
| `approved_at` | When the candidate last approved |
| `created_at`, `updated_at` | When the row was created and last changed (`updated_at` updates itself) |

## profile_drafts

| Column | What it holds |
|---|---|
| `user_id` | The candidate's account. At most one draft at a time: a new upload replaces it |
| `data` | What the AI extracted, same shape as `profiles.data`. The review form edits this |
| `provider` | Which AI produced it: `mistral` or `gemini` (the fallback) |
| `created_at`, `updated_at` | As above |

**Why a separate table and not a column on `profiles`?** RLS works per row. A company allowed
to read an approved profile row would also read any column on it, including an unreviewed draft.

## companies

| Column | What it holds |
|---|---|
| `user_id` | The company's login, created by the admin |
| `name`, `sector`, `description`, `website`, `logo_url` | The "My company" page. The company edits these |
| `disabled` | Set by the admin. A disabled company can no longer see any profile |
| `created_at`, `updated_at` | As above |

## extraction_jobs

| Column | What it holds |
|---|---|
| `id` | The job's id; the "Processing your CV" page asks for its status with it |
| `user_id` | Whose CV it is |
| `kind` | `extract` (read a CV) or `embed` (compute a profile's embedding) |
| `status` | `queued` → `processing` → `done` or `failed` |
| `attempts` | How many times the worker has tried it. After 3, it fails |
| `error_message` | Shown to the candidate when it fails, so plain words only, never a technical error |
| `file_path` | Where the uploaded file waits in the temporary storage bucket. The file is deleted when the job ends |
| `run_after` | The job is not picked before this time. Used to wait after the AI says "too many requests" (429) |
| `started_at`, `finished_at` | When the worker started and finished it |
| `created_at`, `updated_at` | As above. Jobs are handled oldest first |

## The queue functions (for the worker only)

| Function | What it does |
|---|---|
| `claim_next_job()` | Gives the worker the oldest job that may run now and marks it `processing`. Two workers asking at the same time get different jobs (`FOR UPDATE SKIP LOCKED`) |
| `requeue_stuck_jobs()` | Run when the worker starts: jobs cut off by a crash go back to `queued`, or fail if they already had 3 attempts |

Only the server (the service role key) can run them.

## Work on the database locally

You need Docker and the [Supabase CLI](https://supabase.com/docs/guides/local-development).
The local database is the open-source Supabase, the same software as the cloud one.

```bash
supabase start      # starts Postgres, Auth and Storage in Docker (first time: a few minutes)
supabase db reset   # wipes the local database and applies every migration from scratch
supabase test db    # runs the tests in supabase/tests/
supabase stop       # when you're done
```

The local Studio (a dashboard to look at the tables) is at http://127.0.0.1:54623.
Our ports are 546xx, so they don't collide with another local Supabase project.

To change the database: add a new file with `supabase migration new <what_it_does>`, write the SQL,
then run `supabase db reset` and `supabase test db`. Never edit a migration that is already on `main`:
the cloud database has already run it.
