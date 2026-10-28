import subprocess
import sys


def test_worker_starts_and_says_so():
    out = subprocess.run([sys.executable, "-m", "cv_worker", "--once"],
                         check=False, capture_output=True, text=True, timeout=10)
    assert out.returncode == 0, out.stderr
    assert "worker started" in out.stdout
