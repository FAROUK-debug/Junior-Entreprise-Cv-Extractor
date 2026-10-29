# AI provider limits (free tier)

What each dashboard shows on the free plan. Update this when a plan changes.

We use **Google Gemini only** (decided 29 Oct 2026, approved by Ahmed). Mistral was dropped: its free API refused every call
(HTTP 429) until a paid plan was turned on. NVIDIA was skipped for Sprint 1 (agreed with the team).

## Google Gemini (extraction)

Key created in Google AI Studio (aistudio.google.com), stored in `.env` as `GEMINI_API_KEY` (ask Ahmed for the value). Check it with `python scripts/check_keys.py`.

- Model: `gemini-3.5-flash`. On 29 Oct it answered in about 2 s, while `gemini-flash-latest` (3.8) timed out on the free tier
  and `gemini-2.5-flash` is retired for new keys. Change it with `GEMINI_MODEL` in `.env`.
- Free limits, measured 29 Oct: **`gemini-3.5-flash` allows only 20 requests per day** per project (Google's 429 answer:
  "Generate content requests per day limit exceeded on Free Tier", quota counted on `gemini-3.6-flash`, reset after about 20 h).
  Each model has its own quota: `gemini-3.5-flash-lite` still answered after that and handled about 80 CVs the same day
  without hitting a limit, with perfect scores on the 10 labelled CVs (S1-22). 20 a day is far too few for a job fair, so S1-21 now falls back to
  Flash-Lite automatically when Flash is refused. Before the fair: either make Flash-Lite the main model or turn on billing. Exact per-minute limits: AI Studio → Usage / Rate limits.
- 29 Oct: the key is valid, but the first test calls got "high demand, try again later" (HTTP 503) and timeouts.
  The free tier can be busy at peak times; the worker returns `provider_error` / `timeout` and the candidate
  sees "We couldn't read your CV right now, please try again later".
