import json
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from scripts import monthly_asset_report_cron


def config(**overrides):
    values = {
        "supabase_url": "https://example.supabase.co",
        "anon_key": "anon",
        "user_jwt": "jwt",
        "cron_enabled": True,
        "manual_run": False,
        "force": False,
        "dry_run": False,
        "enable_ai_summary": False,
        "strict_secrets": False,
        "year_month": "",
        "provider": "google",
        "timeout": 3,
        "slack_webhook_url": "",
        "discord_webhook_url": "",
    }
    values.update(overrides)
    return monthly_asset_report_cron.CronConfig(**values)


class MonthlyAssetReportCronTest(unittest.TestCase):
    def test_month_rollover_and_previous_month_use_jst(self) -> None:
        now = datetime(2026, 6, 30, 15, 0, tzinfo=timezone.utc)

        self.assertTrue(monthly_asset_report_cron.month_rollover_jst(now))
        self.assertEqual(monthly_asset_report_cron.previous_month_key(now), "2026-06")

    def test_scheduled_run_skips_when_feature_flag_is_off(self) -> None:
        report = monthly_asset_report_cron.build_report(
            config(cron_enabled=False),
            now=datetime(2026, 6, 30, 15, 0, tzinfo=timezone.utc),
        )

        self.assertEqual(report["status"], "skipped")
        self.assertEqual(report["reason"], "feature_flag_off")

    def test_scheduled_run_skips_non_month_rollover(self) -> None:
        report = monthly_asset_report_cron.build_report(
            config(),
            now=datetime(2026, 6, 29, 15, 0, tzinfo=timezone.utc),
        )

        self.assertEqual(report["status"], "skipped")
        self.assertEqual(report["reason"], "not_month_rollover_jst")

    def test_missing_user_jwt_fails_when_cron_enabled(self) -> None:
        report = monthly_asset_report_cron.build_report(
            config(user_jwt=""),
            now=datetime(2026, 6, 30, 15, 0, tzinfo=timezone.utc),
        )

        self.assertEqual(report["status"], "fail")
        self.assertEqual(report["reason"], "missing_ASSET_MONTHLY_REPORT_USER_JWT")

    def test_payload_calls_ai_hub_with_guarded_defaults(self) -> None:
        calls = []

        def requester(url, payload, headers, timeout):
            calls.append((url, payload, headers, timeout))
            return 200, {
                "success": True,
                "status": "feature_flag_off",
                "ai_enabled": False,
                "ai_model": "deterministic-fallback",
            }

        report = monthly_asset_report_cron.build_report(
            config(),
            now=datetime(2026, 6, 30, 15, 0, tzinfo=timezone.utc),
            requester=requester,
        )

        self.assertEqual(report["status"], "pass")
        url, payload, headers, timeout = calls[0]
        self.assertEqual(url, "https://example.supabase.co/functions/v1/ai-hub")
        self.assertEqual(payload["action"], "asset.monthly_report.generate")
        self.assertEqual(payload["year_month"], "2026-06")
        self.assertFalse(payload["enable_ai_summary"])
        self.assertFalse(payload["dry_run"])
        self.assertEqual(headers["Authorization"], "Bearer jwt")
        self.assertEqual(headers["apikey"], "anon")
        self.assertEqual(timeout, 3)

    def test_manual_run_allows_explicit_month_and_dry_run(self) -> None:
        def requester(_url, payload, _headers, _timeout):
            self.assertEqual(payload["year_month"], "2026-05")
            self.assertTrue(payload["dry_run"])
            return 200, {"success": True, "status": "feature_flag_off"}

        report = monthly_asset_report_cron.build_report(
            config(
                cron_enabled=False,
                manual_run=True,
                year_month="2026-05",
                dry_run=True,
            ),
            now=datetime(2026, 6, 10, 2, 0, tzinfo=timezone.utc),
            requester=requester,
        )

        self.assertEqual(report["status"], "pass")

    def test_manual_run_without_secret_skips_unless_strict(self) -> None:
        report = monthly_asset_report_cron.build_report(
            config(manual_run=True, user_jwt=""),
            now=datetime(2026, 6, 10, 2, 0, tzinfo=timezone.utc),
        )

        self.assertEqual(report["status"], "skipped")
        self.assertEqual(report["reason"], "missing_ASSET_MONTHLY_REPORT_USER_JWT")

    def test_cli_writes_report_and_summary_for_safe_skip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report_path = root / "report.json"
            summary_path = root / "summary.md"
            rc = monthly_asset_report_cron.main(
                [
                    "--cron-enabled",
                    "false",
                    "--report",
                    str(report_path),
                    "--summary-md",
                    str(summary_path),
                ]
            )

            self.assertEqual(rc, 0)
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["status"], "skipped")
            self.assertIn("Monthly Asset Report Cron", summary_path.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
