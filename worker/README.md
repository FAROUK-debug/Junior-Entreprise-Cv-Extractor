# Worker (Python)

Reads CVs with the AI and saves the profiles (design §4). It is a plain script that runs forever.
There is no web server: it only talks to the Supabase database.

## Set up (once)

You need Python 3.12 (task S1-02).

```bash
cd worker
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## Run

```bash
python -m cv_worker              # runs forever, Ctrl+C to stop
python -m cv_worker --once       # one pass, then exits
```

It reads its keys from the environment: see the `worker` block of [`../.env.example`](../.env.example).

## Before opening a pull request

```bash
ruff check .
pytest
```

## Where things go

| Path | What |
|---|---|
| `cv_worker/__main__.py` | The loop: claim a job, run it, mark it done or failed (S1-24) |
| `cv_worker/schema.py` | The profile schema, the one source of truth (S1-15) |
| `cv_worker/prompts.py` | The extraction prompt (S1-19) |
| `cv_worker/ai/` | The AI calls: `gemini.py` (extraction), `embed.py` (embeddings, S1-33), `errors.py` |
| `cv_worker/extract.py` | File in, profile out. No database code here (S1-20) |
| `cv_worker/extract_one.py` | `python -m cv_worker.extract_one path/to/cv.pdf`: real extraction on one file, prints the profile |
| `tests/` | `pytest` tests |

A new library goes in `requirements.txt` with an exact version (`name==1.2.3`), and the PR says why.
