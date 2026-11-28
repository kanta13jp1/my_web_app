#!/usr/bin/env python3
"""Unit and contract tests for scripts/pr_review_quota_guard.py (#2700)."""

from __future__ import annotations

import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

import pr_review_quota_guard as guard


class PrReviewQuotaGuardTests(unittest.TestCase):
    def test_consumer_and_enterprise_tier_defaults_and_call_estimation(self) -> None:
        self.assertEqual(guard.default_limit_for_tier("consumer"), 33)
        self.assertEqual(guard.default_limit_for_tier("enterprise"), 100)
        self.assertEqual(guard.estimate_pr_model_calls(2, 80), 1)
        self.assertEqual(guard.estimate_pr_model_calls(16, 1200), 5)

    def test_quota_exhaustion_skips_cleanly_without_error_and_logs_audit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state_file = Path(tmp) / "pr_quota_state.json"
            now = dt.datetime(2026, 11, 25, 6, 0, tzinfo=dt.timezone.utc)

            for pr_num in range(1, 3):
                res = guard.evaluate_pr_review_quota(
                    repository="kanta13jp1/my_web_app",
                    pr_number=pr_num,
                    installation_key="gh-app-1",
                    plan_tier="consumer",
                    daily_limit=2,
                    changed_files=4,
                    diff_lines=100,
                    state_path=state_file,
                    now_utc=now,
                )
                self.assertTrue(res["allowed"])
                self.assertFalse(res["skipped"])
                self.assertTrue(res["isolated_from_general_quota"])

            # 3rd PR exceeds daily_limit=2: must return ok=True, skipped=True, exit 0.
            out_json = Path(tmp) / "out.json"
            gh_out = Path(tmp) / "gh_out.txt"
            rc = guard.main(
                [
                    "--repository",
                    "kanta13jp1/my_web_app",
                    "--pr-number",
                    "3",
                    "--installation-key",
                    "gh-app-1",
                    "--daily-limit",
                    "2",
                    "--state-file",
                    str(state_file),
                    "--output-json",
                    str(out_json),
                    "--github-output",
                    str(gh_out),
                ]
            )
            self.assertEqual(rc, 0)
            payload = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertTrue(payload["ok"])
            self.assertTrue(payload["skipped"])
            self.assertFalse(payload["review_executed"])
            self.assertEqual(payload["status"], "skipped_quota_exceeded")
            self.assertIn("skipped cleanly", payload["skip_reason"])

            gh_text = gh_out.read_text(encoding="utf-8")
            self.assertIn("skipped=true", gh_text)
            self.assertIn("review_executed=false", gh_text)

            state = json.loads(state_file.read_text(encoding="utf-8"))
            self.assertEqual(state["events"][-1]["outcome"], "skipped_quota_exceeded")

    def test_async_reconcile_and_dry_run_isolation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            state_file = Path(tmp) / "pr_quota_state.json"
            now = dt.datetime(2026, 11, 25, 6, 30, tzinfo=dt.timezone.utc)

            dry = guard.evaluate_pr_review_quota(
                repository="kanta13jp1/my_web_app",
                pr_number=99,
                installation_key="gh-app-2",
                dry_run=True,
                state_path=state_file,
                now_utc=now,
            )
            self.assertEqual(dry["pr_reviews_used"], 0)
            self.assertFalse(dry["review_executed"])

            claimed = guard.evaluate_pr_review_quota(
                repository="kanta13jp1/my_web_app",
                pr_number=100,
                installation_key="gh-app-2",
                changed_files=10,
                diff_lines=500,
                state_path=state_file,
                now_utc=now,
            )
            self.assertEqual(claimed["pr_reviews_used"], 1)
            self.assertEqual(claimed["estimated_model_calls"], 2)

            rec = guard.reconcile_async_model_calls(
                repository="kanta13jp1/my_web_app",
                pr_number=100,
                installation_key="gh-app-2",
                estimated_model_calls=2,
                actual_model_calls=6,
                state_path=state_file,
                now_utc=now,
            )
            self.assertTrue(rec["reconciled"])
            self.assertEqual(rec["delta_model_calls"], 4)
            self.assertEqual(rec["pr_review_model_calls_used"], 6)


if __name__ == "__main__":
    unittest.main()
