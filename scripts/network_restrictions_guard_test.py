"""Exercise only the network action guard; never call the management API."""
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / ".github/workflows/fix-supabase-network.yml").read_text(encoding="utf-8")
SECTION = SOURCE.split("      - name: Determine action\n", 1)[1].split("      - name: Check current Network Restrictions", 1)[0]
SCRIPT = textwrap.dedent(SECTION.split("        run: |\n", 1)[1])

class NetworkGuardTest(unittest.TestCase):
    def guard(self, event="workflow_dispatch", ref="refs/heads/main", action="check", confirmation="false"):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "outputs"
            result = subprocess.run(["bash", "-c", SCRIPT], text=True, capture_output=True, timeout=10,
                env={**os.environ, "EVENT_NAME": event, "EVENT_REF": ref, "ACTION_INPUT": action,
                     "CONFIRM_ALLOW_ALL": confirmation, "GITHUB_OUTPUT": str(output)})
            return result, output.read_text() if output.exists() else ""

    def test_manual_check_needs_no_mutation_confirmation(self):
        result, output = self.guard()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "action=check\n")

    def test_allow_all_requires_exact_confirmation(self):
        for value in ["", "false", "TRUE", "1", "true"]:
            with self.subTest(value=value):
                result, output = self.guard(action="allow-all", confirmation=value)
                self.assertEqual(result.returncode == 0, value == "true")
                self.assertEqual(output, "action=allow-all\n" if value == "true" else "")

    def test_push_and_other_events_cannot_authorize(self):
        for event in ["push", "pull_request", "schedule", "workflow_call", ""]:
            with self.subTest(event=event):
                result, output = self.guard(event=event, action="allow-all", confirmation="true")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(output, "")

    def test_non_main_and_unknown_action_rejected(self):
        for ref, action in [("refs/heads/codex/test", "allow-all"), ("refs/tags/main", "allow-all"),
                            ("refs/heads/main", "unexpected"), ("refs/heads/main", "check\ninjected=true")]:
            with self.subTest(ref=ref, action=action):
                result, output = self.guard(ref=ref, action=action, confirmation="true")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(output, "")

    def test_real_trigger_job_and_mutation_wiring(self):
        trigger = SOURCE.split("\nconcurrency:", 1)[0]
        self.assertIn("  workflow_dispatch:", trigger)
        self.assertNotIn("  push:", trigger)
        self.assertNotIn("  schedule:", trigger)
        self.assertIn("default: false", trigger)
        self.assertIn("type: boolean", trigger)
        self.assertIn("name: platform-security-production", SOURCE)
        self.assertIn("deployment: false", SOURCE)
        self.assertIn("if: github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/main'", SOURCE)
        for name in ["Allow all IPs (制限解除)", "Verify after update"]:
            step = SOURCE.split("      - name: " + name + "\n", 1)[1].split("      - name:", 1)[0]
            self.assertIn("inputs.confirm_allow_all == true && steps.action.outputs.action == 'allow-all'", step)
        self.assertNotIn("curl", SCRIPT)
        self.assertIn("python scripts/network_restrictions_guard_test.py",
            (ROOT / ".github/workflows/ci.yml").read_text(encoding="utf-8"))

if __name__ == "__main__":
    unittest.main()
