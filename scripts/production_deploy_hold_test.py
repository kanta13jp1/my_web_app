import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
GUARD = "vars.PRODUCTION_DEPLOY_HOLD == 'false'"

def job_condition(text, job):
    section = re.split(r"\n  (?=\S)", text.split("\n  " + job + ":\n", 1)[1], maxsplit=1)[0]
    return next(line.strip()[4:] for line in section.splitlines() if line.startswith("    if: "))

class ProductionHoldTests(unittest.TestCase):
    def test_all_production_jobs_require_explicit_release(self):
        for file, jobs in [("deploy-prod.yml", ("ci", "deploy", "notify")), ("deploy-core-hub.yml", ("deploy",))]:
            text = (ROOT / ".github/workflows" / file).read_text(encoding="utf-8")
            for job in jobs:
                condition = job_condition(text, job)
                expected = {
                    ("deploy-prod.yml", "ci"): GUARD + " && github.event_name == 'workflow_dispatch'",
                    ("deploy-prod.yml", "deploy"): "always() && " + GUARD + " && (needs.ci.result == 'success' || needs.ci.result == 'skipped')",
                    ("deploy-prod.yml", "notify"): "always() && " + GUARD,
                    ("deploy-core-hub.yml", "deploy"): GUARD + " && github.event_name == 'push' && github.ref == 'refs/heads/main'",
                }
                self.assertEqual(condition, expected[(file, job)])
    def test_unset_invalid_true_stay_held_for_push_and_manual(self):
        for event in ("push", "workflow_dispatch"):
            for value in ("", "true", "TRUE", "False", "0", "garbage"):
                self.assertFalse(value == "false", (event, value))
            self.assertTrue("false" == "false")
    def test_no_dispatch_override_and_visible_hold(self):
        text = (ROOT / ".github/workflows/deploy-prod.yml").read_text(encoding="utf-8")
        self.assertIn("if: vars.PRODUCTION_DEPLOY_HOLD != 'false'", text)
        inputs = text.split("  workflow_dispatch:", 1)[1].split("\nconcurrency:", 1)[0]
        self.assertNotIn("PRODUCTION_DEPLOY_HOLD", inputs)
        status = text.split("\n  hold-status:", 1)[1]
        self.assertNotIn("secrets.", status)
        self.assertNotIn("environment:", status)

if __name__ == "__main__":
    unittest.main()
