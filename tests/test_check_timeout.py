"""Exercise a real short child process, including a hanging descendant on POSIX."""
import os
from pathlib import Path
import subprocess
import sys
import time
import signal
import tempfile
import unittest

WRAPPER = Path(__file__).resolve().parents[1] / "tools/run_godot_check.py"


class CheckTimeoutTests(unittest.TestCase):
    def run_child(self, code, limit="2"):
        env = os.environ.copy(); env["HERO_CHECK_TIMEOUT_SECONDS"] = limit
        return subprocess.run([sys.executable, str(WRAPPER), sys.executable, "-c", code],
                              env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=7)

    def test_success_preserves_unicode_output(self):
        result = self.run_child("print('江湖 · passed')")
        self.assertEqual(result.returncode, 0)
        self.assertIn("江湖 · passed", result.stdout.decode())

    def test_failure_keeps_code_and_stderr(self):
        result = self.run_child("import sys; print('failure detail', file=sys.stderr); sys.exit(7)")
        self.assertEqual(result.returncode, 7)
        self.assertIn(b"failure detail", result.stdout)

    def test_timeout_preserves_partial_error_and_returns_nonzero(self):
        start = time.monotonic()
        result = self.run_child("import time; print('SCRIPT ERROR: fixture', flush=True); time.sleep(5)", ".15")
        self.assertEqual(result.returncode, 124)
        self.assertIn(b"SCRIPT ERROR: fixture", result.stdout)
        self.assertIn(b"exceeded", result.stdout)
        self.assertLess(time.monotonic()-start, 3)

    @unittest.skipUnless(os.name == "posix", "Process-group cleanup is POSIX-specific")
    def test_hanging_descendant_does_not_keep_output_pipe_open(self):
        start = time.monotonic()
        result = self.run_child("import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import time; time.sleep(5)']); print('child started',flush=True); time.sleep(5)", ".15")
        self.assertEqual(result.returncode, 124)
        self.assertLess(time.monotonic()-start, 3)

    def test_invalid_limit_never_runs_command(self):
        for limit in ["0", "-1", "nan", "invalid"]:
            result = self.run_child("print('SHOULD_NOT_RUN')", limit)
            self.assertEqual(result.returncode, 2)
            self.assertNotIn(b"SHOULD_NOT_RUN", result.stdout)

    @unittest.skipUnless(os.name == "posix", "Signal cancellation is verified on POSIX")
    def test_cancellation_stops_child_and_preserves_partial_output(self):
        for requested in [signal.SIGINT, signal.SIGTERM]:
            with tempfile.TemporaryDirectory(prefix="hero-cancel-check-") as folder:
                marker = Path(folder) / "ready"
                code = f"from pathlib import Path; import time; print('started',flush=True); Path({str(marker)!r}).write_text('ready'); time.sleep(5)"
                process = subprocess.Popen([sys.executable, str(WRAPPER), sys.executable, "-c", code], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic()+3
                    while not marker.exists() and time.monotonic()<deadline: time.sleep(.01)
                    self.assertTrue(marker.exists())
                    process.send_signal(requested)
                    output, _ = process.communicate(timeout=3)
                    self.assertEqual(process.returncode, 128+requested)
                    self.assertIn(b"started", output)
                finally:
                    if process.poll() is None: process.kill(); process.communicate()


if __name__ == "__main__": unittest.main()
