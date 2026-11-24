#!/usr/bin/env python3
"""Offline unit tests for scripts/ai_action_budget_guard.py (#2609)."""

from __future__ import annotations

import io
from pathlib import Path
import sys
import unittest
from unittest import mock
from urllib import error as urllib_error

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))
import ai_action_budget_guard as budget_guard


class AiActionBudgetGuardTests(unittest.TestCase):
    def test_cost_calculation_and_validation(self) -> None:
        # gemini-2.5-flash: 0.15 in / 0.60 out per 1M
        cost = budget_guard.estimate_action_cost_usd(
            model_id="gemini-2.5-flash",
            prompt_units=1_000_000,
            completion_units=500_000,
        )
        self.assertAlmostEqual(cost, 0.45)

        with self.assertRaises(ValueError):
            budget_guard.estimate_action_cost_usd(
                model_id="gpt-4o",
                prompt_units=-1,
                completion_units=10,
            )

    def test_warning_80_and_auto_pause_100_fail_closed(self) -> None:
        entries_85 = [
            {"action_name": "a1", "model_id": "gpt-4o", "estimated_usd": 42.50, "billing_month": "2026-11"},
            {"action_name": "old", "model_id": "gpt-4o", "estimated_usd": 99.00, "billing_month": "2026-10"},
        ]
        warn_eval = budget_guard.evaluate_monthly_budget(
            ledger_entries=entries_85,
            billing_month="2026-11",
            monthly_usd_cap=50.0,
        )
        self.assertEqual(warn_eval.tier, "warning_80")
        self.assertTrue(warn_eval.warning_80_triggered)
        self.assertFalse(warn_eval.auto_pause_triggered)
        self.assertEqual(warn_eval.exit_code, 0)
        self.assertIsNotNone(budget_guard.build_slack_alert_payload(warn_eval))
        self.assertIsNone(budget_guard.build_github_issue_alert_payload(warn_eval))

        entries_102 = entries_85 + [
            {"action_name": "a2", "model_id": "claude-sonnet-4", "estimated_usd": 8.50, "billing_month": "2026-11"},
        ]
        pause_eval = budget_guard.evaluate_monthly_budget(
            ledger_entries=entries_102,
            billing_month="2026-11",
            monthly_usd_cap=50.0,
        )
        self.assertEqual(pause_eval.tier, "paused_100")
        self.assertTrue(pause_eval.auto_pause_triggered)
        self.assertTrue(pause_eval.effective_paused)
        self.assertEqual(pause_eval.exit_code, 2)
        issue_payload = budget_guard.build_github_issue_alert_payload(pause_eval)
        self.assertIsNotNone(issue_payload)
        self.assertIn("USD 51.0000", str(issue_payload["body"]))

    def test_pre_paused_config_blocks_even_below_cap(self) -> None:
        paused_eval = budget_guard.evaluate_monthly_budget(
            ledger_entries=[{"action_name": "x", "estimated_usd": 1.0, "billing_month": "2026-11"}],
            billing_month="2026-11",
            monthly_usd_cap=50.0,
            pre_paused=True,
        )
        self.assertTrue(paused_eval.effective_paused)
        self.assertEqual(paused_eval.tier, "pre_paused")
        self.assertEqual(paused_eval.exit_code, 2)

    def test_notification_http_error_sanitizes_query_and_raises_runtime_error(self) -> None:
        endpoint = "https://hooks.slack.example/services/test?sig=must_not_leak"
        http_err = urllib_error.HTTPError(
            url=endpoint,
            code=500,
            msg="Internal Server Error",
            hdrs=None,  # type: ignore[arg-type]
            fp=io.BytesIO(b"{}"),
        )
        with mock.patch("ai_action_budget_guard.urllib_request.urlopen", side_effect=http_err):
            with self.assertRaises(RuntimeError) as ctx:
                budget_guard.post_json_notification(endpoint, {"text": "alert"})
        self.assertIn("500", str(ctx.exception))
        self.assertNotIn("must_not_leak", str(ctx.exception))
        self.assertNotIn("?", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
