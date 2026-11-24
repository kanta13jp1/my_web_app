import json
import os
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from evaluate_quota_thresholds import (  # noqa: E402
    build_admin_issue_payload,
    build_slack_webhook_payload,
    compute_usage_pct,
    evaluate_tool_payload,
    main,
)


class EvaluateQuotaThresholdsTest(unittest.TestCase):
    def test_computes_usage_pct_across_cost_percentage_and_credits(self) -> None:
        self.assertEqual(compute_usage_pct({"tool": "anthropic", "cost_usd": 40.0}), 80.0)
        self.assertEqual(compute_usage_pct({"tool": "openai", "cost_usd": 20.0}), 100.0)
        self.assertEqual(compute_usage_pct({"tool": "actions_minutes", "pct": 85.5}), 85.5)
        self.assertEqual(
            compute_usage_pct({"tool": "hedra", "used": 90, "remaining": 10}),
            90.0,
        )
        self.assertIsNone(compute_usage_pct({"tool": "gemini", "models_count": 5}))

    def test_evaluates_80_warning_and_100_autopause_plus_silent_pause_detection(self) -> None:
        warn = evaluate_tool_payload(
            {"tool": "anthropic", "cost_usd": 42.5},
            now_iso="2026-11-24T03:00:00Z",
        )
        self.assertIsNotNone(warn)
        assert warn is not None
        self.assertEqual(warn.tier, "warning_80")
        self.assertTrue(warn.should_warn_80)
        self.assertFalse(warn.should_auto_pause)
        self.assertFalse(warn.should_create_admin_issue)
        self.assertFalse(warn.silent_pause_detected)

        paused = evaluate_tool_payload(
            {"tool": "openai", "cost_usd": 20.0, "upstream_paused": False},
            existing_state={"auto_paused": False, "resumed_by_admin": False},
            now_iso="2026-11-24T03:00:00Z",
        )
        self.assertIsNotNone(paused)
        assert paused is not None
        self.assertEqual(paused.tier, "paused_100")
        self.assertTrue(paused.should_warn_80)
        self.assertTrue(paused.should_auto_pause)
        self.assertTrue(paused.should_create_admin_issue)
        self.assertTrue(paused.silent_pause_detected)

    def test_builds_slack_payload_and_deduplicates_admin_issues(self) -> None:
        ev = evaluate_tool_payload(
            {"tool": "actions_minutes", "pct": 100.0},
            existing_state={"auto_paused": False, "resumed_by_admin": False},
            now_iso="2026-11-24T03:00:00Z",
        )
        assert ev is not None
        slack = build_slack_webhook_payload([ev])
        self.assertIsNotNone(slack)
        assert slack is not None
        self.assertIn("AUTO-PAUSE (100%)", str(slack["text"]))
        self.assertIn("SILENT PAUSE DETECTED", str(slack["text"]))

        issue_new = build_admin_issue_payload(ev, existing_open_issues=[])
        self.assertIsNotNone(issue_new)
        assert issue_new is not None
        self.assertIn("[quota-autopause:actions_minutes]", str(issue_new["title"]))

        dedup = build_admin_issue_payload(
            ev,
            existing_open_issues=[
                {"title": "[quota-autopause:actions_minutes] already open", "body": ""},
            ],
        )
        self.assertIsNone(dedup)

    def test_fails_closed_when_live_flags_lack_credentials_and_runs_dry_run(self) -> None:
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(main(["--apply"]), 1)
            self.assertEqual(main(["--notify-slack"]), 1)
            self.assertEqual(main(["--create-issues"]), 1)

        with tempfile.TemporaryDirectory() as tmpdir:
            in_path = Path(tmpdir) / "usage.json"
            out_path = Path(tmpdir) / "eval.json"
            in_path.write_text(
                json.dumps([
                    {"tool": "anthropic", "cost_usd": 45.0},
                    {"tool": "openai", "cost_usd": 22.0, "upstream_paused": False},
                ]),
                encoding="utf-8",
            )
            rc = main([
                "--input-json",
                str(in_path),
                "--dry-run",
                "--json-out",
                str(out_path),
            ])
            self.assertEqual(rc, 0)
            results = json.loads(out_path.read_text(encoding="utf-8"))
            self.assertEqual(len(results), 2)
            self.assertEqual(results[0]["tier"], "warning_80")
            self.assertEqual(results[1]["tier"], "paused_100")
            self.assertTrue(results[1]["silent_pause_detected"])


if __name__ == "__main__":
    unittest.main()
