#!/usr/bin/env python3
"""Tests for the weekly user-growth PDCA funnel auditor."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from scripts.growth_pdca_audit import (
    GrowthSnapshot,
    diagnose_pdca,
    format_markdown_report,
    main,
)


class GrowthPdcaAuditTest(unittest.TestCase):
    def test_cycle0_baseline_identifies_trial_outage_and_save_drop(self) -> None:
        snapshot = GrowthSnapshot.from_dict(
            {
                "window_label": "Cycle #0 (2026-11-23 baseline)",
                "captured_at": "2026-11-23T03:35:00+09:00",
                "total_users": 61,
                "users_last_30d": 0,
                "days_since_latest_signup": 117,
                "days_since_latest_trial": 51,
                "x_posts_tracked": 69,
                "x_media_posts": 0,
                "x_impressions": 50390,
                "x_url_clicks": 14,
                "x_profile_clicks": 100,
                "lp_views": 270,
                "trial_starts": 77,
                "trial_successes": 0,
                "save_ctas": 0,
                "signup_submits": 2,
                "signup_completes": 0,
            }
        )
        report = diagnose_pdca(snapshot)
        self.assertEqual(report.primary_bottleneck, "trial_provider_outage")
        self.assertEqual(report.secondary_bottleneck, "trial_to_save_drop")
        self.assertEqual(report.severity, "P0")
        self.assertIn("Gemini", report.single_variable_hypothesis)
        md = format_markdown_report(report)
        self.assertIn("ユーザー増加 PDCA 監査レポート", md)
        self.assertIn("50,390", md)

    def test_detects_trial_to_save_drop_when_ai_trial_is_healthy(self) -> None:
        snapshot = GrowthSnapshot.from_dict(
            {
                "window_label": "Cycle #1",
                "captured_at": "2026-11-30T09:00:00+09:00",
                "total_users": 61,
                "users_last_30d": 0,
                "days_since_latest_signup": 124,
                "days_since_latest_trial": 0,
                "x_posts_tracked": 10,
                "x_media_posts": 8,
                "x_impressions": 4000,
                "x_url_clicks": 45,
                "x_profile_clicks": 30,
                "lp_views": 180,
                "trial_starts": 60,
                "trial_successes": 58,
                "save_ctas": 1,
                "signup_submits": 1,
                "signup_completes": 0,
            }
        )
        report = diagnose_pdca(snapshot)
        self.assertEqual(report.primary_bottleneck, "trial_to_save_drop")
        self.assertIn("5つの短い質問", report.single_variable_hypothesis)

    def test_detects_x_click_starvation_when_impressions_lack_media_or_ctr(self) -> None:
        snapshot = GrowthSnapshot.from_dict(
            {
                "window_label": "Cycle #2",
                "captured_at": "2026-12-07T09:00:00+09:00",
                "total_users": 65,
                "users_last_30d": 4,
                "days_since_latest_signup": 2,
                "days_since_latest_trial": 0,
                "x_posts_tracked": 12,
                "x_media_posts": 0,
                "x_impressions": 12000,
                "x_url_clicks": 2,
                "x_profile_clicks": 8,
                "lp_views": 120,
                "trial_starts": 30,
                "trial_successes": 30,
                "save_ctas": 8,
                "signup_submits": 4,
                "signup_completes": 3,
            }
        )
        report = diagnose_pdca(snapshot)
        self.assertEqual(report.primary_bottleneck, "x_click_starvation")
        self.assertAlmostEqual(report.rates["x_media_ratio_pct"], 0.0)

    def test_healthy_funnel_advances_to_viral_iteration(self) -> None:
        snapshot = GrowthSnapshot.from_dict(
            {
                "window_label": "Cycle #4",
                "captured_at": "2026-12-21T09:00:00+09:00",
                "total_users": 90,
                "users_last_30d": 29,
                "days_since_latest_signup": 0,
                "days_since_latest_trial": 0,
                "x_posts_tracked": 10,
                "x_media_posts": 8,
                "x_impressions": 8000,
                "x_url_clicks": 120,
                "x_profile_clicks": 60,
                "lp_views": 220,
                "trial_starts": 80,
                "trial_successes": 78,
                "save_ctas": 24,
                "signup_submits": 18,
                "signup_completes": 12,
            }
        )
        report = diagnose_pdca(snapshot)
        self.assertEqual(report.primary_bottleneck, "healthy_iteration")
        self.assertEqual(report.severity, "P2")

    def test_cli_outputs_valid_json_from_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            src = root / "snap.json"
            out = root / "out.json"
            src.write_text(
                json.dumps(
                    {
                        "window_label": "cli-test",
                        "lp_views": 50,
                        "trial_starts": 0,
                    }
                ),
                encoding="utf-8",
            )
            rc = main(["--from-json", str(src), "--format", "json", "--output", str(out)])
            self.assertEqual(rc, 0)
            payload = json.loads(out.read_text(encoding="utf-8"))
            self.assertEqual(payload["primary_bottleneck"], "trial_provider_outage")


if __name__ == "__main__":
    unittest.main()
