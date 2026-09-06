"""Run notification workflow shell with synthetic responses; never contact a service."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / ".github/workflows/wbs-user-tasks-notify.yml").read_text(encoding="utf-8")

def block(name):
    section = SOURCE.split("      - name: " + name + "\n", 1)[1].split("\n      - name:", 1)[0]
    return textwrap.dedent(section.split("        run: |\n", 1)[1])

class NotifyTest(unittest.TestCase):
    def run_step(self, name, response="", status="200", transport="0", limit="10", key="synthetic-key"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fixture = root / "fixture.json"
            fixture.write_text(response, encoding="utf-8")
            mock = r"""
curl() {
  printf 'called' > "$CALL_MARKER"
  while [ "$#" -gt 0 ]; do
    if [ "$1" = "-o" ]; then cp "$FIXTURE" "$2"; shift
    elif [ "$1" = "-d" ]; then printf '%s' "$2" > "$REQUEST_FILE"; shift; fi
    shift
  done
  printf '%s' "$FAKE_STATUS"
  return "$FAKE_TRANSPORT"
}
"""
            result = subprocess.run(
                ["bash", "-c", mock + block(name)], text=True, capture_output=True, timeout=10,
                env={**os.environ, "SUPABASE_URL": "https://example.invalid",
                     "SUPABASE_ANON_KEY": key, "LIMIT": limit, "TMPDIR": directory,
                     "FIXTURE": str(fixture), "CALL_MARKER": str(root / "called"),
                     "REQUEST_FILE": str(root / "request.json"),
                     "FAKE_STATUS": status, "FAKE_TRANSPORT": transport},
            )
            self.assertNotIn("private-response-canary", result.stdout + result.stderr)
            self.assertNotIn("synthetic-key", result.stdout + result.stderr)
            self.assertEqual(list(root.glob("tmp.*")), [])
            if (root / "called").exists():
                request = json.loads((root / "request.json").read_text(encoding="utf-8"))
                self.assertEqual(request, {"action": "wbs.notify_user_tasks", "send_slack": True, "limit": int(limit)})
            return result, (root / "called").exists()

    def test_missing_key_fails_without_request(self):
        result, called = self.run_step("Step 1 - Secret presence check", key="")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(called)
        self.assertEqual(self.run_step("Step 1 - Secret presence check")[0].returncode, 0)

    def test_only_aggregate_success_output(self):
        result, called = self.run_step("Step 2 - Call wbs.notify_user_tasks",
            json.dumps({"user_tasks_count": 3, "tasks": ["private-response-canary"]}))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(called)
        self.assertIn("Notified 3", result.stdout)

    def test_invalid_response_is_not_logged(self):
        for payload in ["private-response-canary", "[]", "{}", '{"user_tasks_count":true}',
                        '{"user_tasks_count":-1}', '{"user_tasks_count":"private-response-canary"}']:
            with self.subTest(payload=payload):
                result, _ = self.run_step("Step 2 - Call wbs.notify_user_tasks", payload)
                self.assertNotEqual(result.returncode, 0)

    def test_http_and_transport_failures(self):
        for status, transport in [("500", "0"), ("401", "0"), ("200", "28"), ("bad", "0")]:
            with self.subTest(status=status, transport=transport):
                result, _ = self.run_step("Step 2 - Call wbs.notify_user_tasks",
                    "private-response-canary", status, transport)
                self.assertNotEqual(result.returncode, 0)

    def test_invalid_limit_never_calls(self):
        for limit in ["0", "101", "-1", "1.2", "1;echo private-response-canary", ""]:
            with self.subTest(limit=limit):
                result, called = self.run_step("Step 2 - Call wbs.notify_user_tasks", limit=limit)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(called)

    def test_no_fixed_key_or_skip_gate(self):
        self.assertNotRegex(SOURCE, r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.")
        self.assertIn("SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}", SOURCE)
        self.assertNotIn("steps.precheck.outputs.skip", SOURCE)
        self.assertIn("python scripts/wbs_notify_privacy_test.py",
                      (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"))

if __name__ == "__main__":
    unittest.main()
