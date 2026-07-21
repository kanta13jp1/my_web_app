#!/usr/bin/env python3

from __future__ import annotations

import unittest
import urllib.error
from datetime import datetime, timezone

from daily_anomaly_scan import (
    ScanConfig,
    build_report,
    is_eligible_auth_user,
    notify_failure,
    scan_user,
)


USER_A = "8d2cc7d2-34f1-4eca-9f6c-0f84c23163d0"
USER_B = "7a6f7086-abef-4e70-8a94-9fc15598c5fe"


def config(**overrides: object) -> ScanConfig:
    defaults: dict[str, object] = {
        "supabase_url": "https://example.supabase.co",
        "service_role_key": "service-secret",
        "cron_enabled": True,
        "manual_run": False,
        "confirm_all_users": False,
        "user_id": "",
        "target_month": "2026-06",
        "max_attempts": 3,
        "workers": 1,
        "timeout": 10,
        "slack_webhook_url": "",
        "discord_webhook_url": "",
    }
    defaults.update(overrides)
    return ScanConfig(**defaults)  # type: ignore[arg-type]


class DailyAnomalyScanTest(unittest.TestCase):
    def test_eligible_users_exclude_anonymous_deleted_and_current_ban(self) -> None:
        now = datetime(2026, 7, 21, tzinfo=timezone.utc)
        self.assertTrue(is_eligible_auth_user({"id": USER_A}, now))
        self.assertFalse(
            is_eligible_auth_user({"id": USER_A, "is_anonymous": True}, now)
        )
        self.assertFalse(
            is_eligible_auth_user({"id": USER_A, "deleted_at": "2026-07-01"}, now)
        )
        self.assertFalse(
            is_eligible_auth_user(
                {"id": USER_A, "banned_until": "2026-07-22T00:00:00Z"}, now
            )
        )
        self.assertTrue(
            is_eligible_auth_user(
                {"id": USER_A, "banned_until": "2026-07-20T00:00:00Z"}, now
            )
        )

    def test_scheduled_run_skips_while_feature_flag_is_off(self) -> None:
        report = build_report(config(cron_enabled=False))
        self.assertEqual(report["status"], "skipped")
        self.assertEqual(report["reason"], "feature_flag_off")

    def test_manual_all_user_run_requires_confirmation(self) -> None:
        report = build_report(config(manual_run=True, cron_enabled=False))
        self.assertEqual(report["status"], "skipped")
        self.assertEqual(report["reason"], "manual_all_users_not_confirmed")

    def test_invalid_target_month_fails_before_user_discovery(self) -> None:
        report = build_report(config(target_month="2026-13"))
        self.assertEqual(report["status"], "fail")
        self.assertEqual(report["reason"], "invalid_target_month")

    def test_report_scans_only_eligible_users(self) -> None:
        seen: list[str] = []

        def list_users(_: ScanConfig) -> list[dict[str, object]]:
            return [
                {"id": USER_A},
                {"id": USER_B, "is_anonymous": True},
                {"id": "invalid"},
            ]

        def scanner(_: ScanConfig, user_id: str) -> dict[str, object]:
            seen.append(user_id)
            return {
                "status": "pass",
                "user_ref": "ref",
                "attempts": 1,
                "anomalies_detected": 2,
                "warnings": 0,
            }

        report = build_report(config(), user_lister=list_users, scanner=scanner)
        self.assertEqual(seen, [USER_A])
        self.assertEqual(report["status"], "pass")
        self.assertEqual(report["users_discovered"], 3)
        self.assertEqual(report["users_eligible"], 1)
        self.assertEqual(report["anomalies_detected"], 2)

    def test_transient_edge_function_failure_is_retried(self) -> None:
        calls = 0
        sleeps: list[float] = []

        def requester(
            _: str,
            __: dict[str, object],
            ___: dict[str, str],
            ____: int,
        ) -> tuple[int, dict[str, object]]:
            nonlocal calls
            calls += 1
            if calls < 3:
                raise urllib.error.URLError("temporary")
            return 200, {
                "success": True,
                "status": "ok",
                "anomalies_detected": 1,
                "warnings": [],
            }

        result = scan_user(
            config(),
            USER_A,
            requester=requester,  # type: ignore[arg-type]
            sleeper=sleeps.append,
        )
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["attempts"], 3)
        self.assertEqual(sleeps, [1.0, 2.0])

    def test_non_retryable_failure_stops_after_first_attempt(self) -> None:
        calls = 0

        def requester(
            _: str,
            __: dict[str, object],
            ___: dict[str, str],
            ____: int,
        ) -> tuple[int, dict[str, object]]:
            nonlocal calls
            calls += 1
            error = urllib.error.HTTPError("url", 401, "unauthorized", {}, None)
            error.read = lambda: b'{"error":"unauthorized"}'  # type: ignore[method-assign]
            raise error

        result = scan_user(
            config(),
            USER_A,
            requester=requester,  # type: ignore[arg-type]
            sleeper=lambda _: None,
        )
        self.assertEqual(calls, 1)
        self.assertEqual(result["status"], "fail")
        self.assertEqual(result["reason"], "http_401")

    def test_failure_notification_uses_configured_channels(self) -> None:
        delivered: list[tuple[str, dict[str, object]]] = []

        def poster(url: str, payload: dict[str, object], _: int) -> None:
            delivered.append((url, payload))

        channels = notify_failure(
            config(slack_webhook_url="https://slack", discord_webhook_url="https://discord"),
            {"reason": "user_scan_failed", "users_eligible": 2, "users_failed": 1},
            poster=poster,  # type: ignore[arg-type]
        )
        self.assertEqual(channels, ["slack", "discord"])
        self.assertEqual([item[0] for item in delivered], ["https://slack", "https://discord"])


if __name__ == "__main__":
    unittest.main()
