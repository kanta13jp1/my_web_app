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
    build_state_row_payload,
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

    def test_resumed_by_admin_suppresses_autopause_and_issue_recreation(self) -> None:
        resumed = evaluate_tool_payload(
            {"tool": "openai", "cost_usd": 21.0, "upstream_paused": False},
            existing_state={"auto_paused": False, "resumed_by_admin": True},
            now_iso="2026-11-24T04:00:00Z",
        )
        assert resumed is not None
        self.assertFalse(resumed.should_auto_pause)
        self.assertFalse(resumed.should_create_admin_issue)
        self.assertFalse(resumed.silent_pause_detected)

        row_resumed = build_state_row_payload(
            resumed,
            prior_state={
                "resumed_by_admin": True,
                "warning_80_sent": True,
                "warning_80_sent_at": "2026-11-23T00:00:00Z",
                "paused_at": "2026-11-23T12:00:00Z",
                "admin_issue_number": 555,
            },
        )
        self.assertFalse(row_resumed["auto_paused"])
        self.assertTrue(row_resumed["resumed_by_admin"])
        self.assertEqual(row_resumed["warning_80_sent_at"], "2026-11-23T00:00:00Z")
        self.assertEqual(row_resumed["paused_at"], "2026-11-23T12:00:00Z")
        self.assertEqual(row_resumed["admin_issue_number"], 555)

    def test_cycle_reset_clears_flags_and_live_main_prefetches_existing_state(self) -> None:
        normal = evaluate_tool_payload(
            {"tool": "anthropic", "cost_usd": 10.0},
            now_iso="2026-12-01T00:15:00Z",
        )
        assert normal is not None
        reset_row = build_state_row_payload(
            normal,
            prior_state={
                "warning_80_sent": True,
                "warning_80_sent_at": "2026-11-20T00:00:00Z",
                "auto_paused": True,
                "paused_at": "2026-11-25T00:00:00Z",
                "resumed_by_admin": True,
                "admin_issue_number": 444,
            },
        )
        self.assertFalse(reset_row["warning_80_sent"])
        self.assertIsNone(reset_row["warning_80_sent_at"])
        self.assertFalse(reset_row["auto_paused"])
        self.assertIsNone(reset_row["paused_at"])
        self.assertFalse(reset_row["resumed_by_admin"])
        self.assertIsNone(reset_row["admin_issue_number"])

        posted_rows: list[dict[str, object]] = []
        created_issues: list[dict[str, object]] = []

        def fake_http(url: str, *, method: str = "GET", headers: dict[str, str], payload: object | None = None, timeout: int = 15) -> tuple[int, object]:
            if method == "GET" and "ai_quota_pause_state" in url:
                return (
                    200,
                    [
                        {
                            "tool": "openai",
                            "auto_paused": False,
                            "resumed_by_admin": False,
                            "warning_80_sent": True,
                            "warning_80_sent_at": "2026-11-23T00:00:00Z",
                        },
                    ],
                )
            if method == "GET" and "/issues" in url:
                return (200, [])
            if method == "POST" and "/issues" in url:
                assert isinstance(payload, dict)
                created_issues.append(payload)
                return (201, {"number": 777})
            if method == "POST" and "ai_quota_pause_state" in url:
                assert isinstance(payload, dict)
                posted_rows.append(payload)
                return (201, {})
            return (200, {})

        with tempfile.TemporaryDirectory() as tmpdir:
            out_json = Path(tmpdir) / "live_eval.json"
            with (
                patch.dict(
                    os.environ,
                    {
                        "SUPABASE_SERVICE_ROLE_KEY": "sb",
                        "GITHUB_TOKEN": "gh",
                        "GITHUB_REPOSITORY": "kanta13jp1/my_web_app",
                        "OPENAI_USAGE": json.dumps({"tool": "openai", "cost_usd": 20.5}),
                    },
                    clear=True,
                ),
                patch("evaluate_quota_thresholds._http_json", side_effect=fake_http),
            ):
                rc = main([
                    "--from-env",
                    "--apply",
                    "--create-issues",
                    "--json-out",
                    str(out_json),
                ])
            self.assertEqual(rc, 0)
            live_eval = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(len(live_eval), 1)
            self.assertTrue(live_eval[0]["silent_pause_detected"])
            self.assertEqual(len(created_issues), 1)
            self.assertEqual(len(posted_rows), 1)
            self.assertEqual(posted_rows[0]["admin_issue_number"], 777)
            self.assertEqual(posted_rows[0]["warning_80_sent_at"], "2026-11-23T00:00:00Z")
            self.assertTrue(posted_rows[0]["auto_paused"])


if __name__ == "__main__":
    unittest.main()
