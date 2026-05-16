import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "release_readiness_gate.py"
spec = importlib.util.spec_from_file_location("release_readiness_gate", SCRIPT)
release_readiness_gate = importlib.util.module_from_spec(spec)
assert spec.loader is not None
sys.modules[spec.name] = release_readiness_gate
spec.loader.exec_module(release_readiness_gate)


class ReleaseReadinessGateTest(unittest.TestCase):
    def test_join_url_normalizes_slashes(self):
        self.assertEqual(
            release_readiness_gate.join_url("https://example.com/", "/project-gantt"),
            "https://example.com/project-gantt",
        )
        self.assertEqual(
            release_readiness_gate.join_url("https://example.com", "referral"),
            "https://example.com/referral",
        )

    def test_success_json_requires_dict_and_no_false_success_flag(self):
        self.assertTrue(release_readiness_gate.success_json({"success": True}))
        self.assertTrue(release_readiness_gate.success_json({"ok": True}))
        self.assertFalse(release_readiness_gate.success_json({"success": False}))
        self.assertFalse(release_readiness_gate.success_json([{"success": True}]))

    def test_render_markdown_counts_failures_and_skips(self):
        results = [
            release_readiness_gate.CheckResult(
                name="route /",
                category="production_http",
                status="success",
                detail="ok",
                target="https://example.com/",
                http_status=200,
            ),
            release_readiness_gate.CheckResult(
                name="Slack webhook",
                category="notification",
                status="skip",
                detail="missing",
            ),
            release_readiness_gate.CheckResult(
                name="notion.preflight_wbs",
                category="edge_hub",
                status="failure",
                detail="schema mismatch",
                http_status=200,
            ),
        ]
        rendered = "\n".join(release_readiness_gate.render_markdown(results))
        self.assertIn("- Overall: `failure`", rendered)
        self.assertIn("- Failed checks: `1`", rendered)
        self.assertIn("- Skipped checks: `1`", rendered)
        self.assertIn("notion.preflight_wbs", rendered)

    def test_write_json_report_preserves_success_flag(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "release-readiness-test.json"
            release_readiness_gate.write_json_report(
                str(output),
                [
                    release_readiness_gate.CheckResult(
                        name="route /",
                        category="production_http",
                        status="success",
                        detail="ok",
                    )
                ],
            )
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertTrue(payload["success"])
            self.assertEqual(payload["results"][0]["name"], "route /")


if __name__ == "__main__":
    unittest.main()
