"""Entry point: `python -m cv_worker`. Runs forever; `--once` does a single pass and exits (for tests).

S1-24 replaces the body of the loop with: claim the next job, run it, mark it done or failed.
"""

import sys
import time

POLL_SECONDS = 3


def main() -> None:
    print("worker started", flush=True)
    while True:
        # S1-24: claim and run the next job here.
        if "--once" in sys.argv:
            return
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
