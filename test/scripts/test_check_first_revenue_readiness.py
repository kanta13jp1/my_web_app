#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

import check_first_revenue_readiness as readiness  # noqa: E402


class FirstRevenueReadinessTest(unittest.TestCase):
    def test_summarizes_live_checkout_response(self) -> None:
        summary = readiness.summarize_checkout_response(
            {
                "success": True,
                "id": "cs_live_123",
                "checkout_url": "https://checkout.stripe.com/c/pay/cs_live_123",
                "amount_jpy": 100,
            }
        )

        self.assertEqual(summary["mode"], "live")
        self.assertEqual(summary["checkout_host"], "checkout.stripe.com")
        self.assertEqual(summary["amount_jpy"], 100)

    def test_rejects_test_checkout_when_live_is_required(self) -> None:
        summary = readiness.summarize_checkout_response(
            {
                "success": True,
                "id": "cs_test_123",
                "checkout_url": "https://checkout.stripe.com/c/pay/cs_test_123",
                "amount_jpy": 100,
            }
        )

        errors = readiness.validate_checkout(
            summary,
            expected_mode="live",
            min_charge_jpy=50,
        )

        self.assertTrue(any("expected 'live'" in error for error in errors))

    def test_rejects_charge_below_jpy_minimum(self) -> None:
        summary = readiness.summarize_checkout_response(
            {
                "success": True,
                "id": "cs_live_123",
                "checkout_url": "https://checkout.stripe.com/c/pay/cs_live_123",
                "amount_jpy": 1,
            }
        )

        errors = readiness.validate_checkout(
            summary,
            expected_mode="live",
            min_charge_jpy=50,
        )

        self.assertTrue(any("below 50 JPY" in error for error in errors))

    def test_accepts_paid_supporter_webhook_evidence(self) -> None:
        summary = readiness.summarize_webhook_rows(
            [
                {
                    "created_at": "2026-06-27T12:00:00Z",
                    "metadata": {
                        "payment_status": "paid",
                        "currency": "jpy",
                        "amount_total": 100,
                        "stripe_checkout_session_id": "cs_live_123",
                        "stripe_payment_intent_id": "pi_live_123",
                    },
                }
            ]
        )

        self.assertEqual(
            readiness.validate_webhook_evidence(summary, min_charge_jpy=50),
            [],
        )

    def test_rejects_missing_webhook_payment_ids(self) -> None:
        summary = readiness.summarize_webhook_rows(
            [
                {
                    "created_at": "2026-06-27T12:00:00Z",
                    "metadata": {
                        "payment_status": "paid",
                        "currency": "jpy",
                        "amount_total": 100,
                    },
                }
            ]
        )

        errors = readiness.validate_webhook_evidence(summary, min_charge_jpy=50)

        self.assertTrue(
            any("stripe_checkout_session_id" in error for error in errors)
        )
        self.assertTrue(any("stripe_payment_intent_id" in error for error in errors))

    def test_accepts_bank_credit_of_at_least_one_jpy(self) -> None:
        summary = readiness.summarize_bank_evidence(
            {
                "statement_date": "2026-07-03",
                "credited_amount_jpy": 1,
                "stripe_payout_id": "po_live_123",
                "bank_reference": "redacted statement line",
            }
        )

        self.assertEqual(readiness.validate_bank_evidence(summary), [])

    def test_rejects_bank_evidence_without_credit(self) -> None:
        summary = readiness.summarize_bank_evidence(
            {
                "statement_date": "2026-07-03",
                "credited_amount_jpy": 0,
                "stripe_payout_id": "po_live_123",
                "bank_reference": "redacted statement line",
            }
        )

        errors = readiness.validate_bank_evidence(summary)

        self.assertTrue(any("at least 1 JPY" in error for error in errors))

    def test_classifies_test_checkout_as_live_secret_required(self) -> None:
        stage = readiness.classify_revenue_stage(
            {
                "checks": {
                    "checkout": {
                        "success": True,
                        "mode": "test",
                        "checkout_host": "checkout.stripe.com",
                        "amount_jpy": 100,
                    }
                },
                "errors": ["Checkout session is 'test'; expected 'live'."],
            }
        )

        self.assertEqual(stage["stage"], "live_secret_required")
        self.assertFalse(stage["goal_complete"])

    def test_classifies_live_checkout_ready_for_real_payment(self) -> None:
        stage = readiness.classify_revenue_stage(
            {
                "checks": {
                    "checkout": {
                        "success": True,
                        "mode": "live",
                        "checkout_host": "checkout.stripe.com",
                        "amount_jpy": 100,
                    }
                },
                "errors": [],
            }
        )

        self.assertEqual(stage["stage"], "live_checkout_ready_for_real_payment")
        self.assertFalse(stage["goal_complete"])

    def test_summarizes_expired_checkout_probe(self) -> None:
        summary = readiness.summarize_checkout_expiration_response(
            "cs_live_123",
            {"status": "expired"},
        )

        self.assertTrue(summary["attempted"])
        self.assertEqual(summary["mode"], "live")
        self.assertTrue(summary["expired"])
        self.assertEqual(summary["status"], "expired")

    def test_classifies_paid_webhook_as_waiting_for_bank_credit(self) -> None:
        stage = readiness.classify_revenue_stage(
            {
                "checks": {
                    "webhook": {
                        "paid_jpy_row_count": 1,
                        "latest_amount_jpy": 100,
                        "latest_checkout_session_id": "cs_live_123",
                        "latest_payment_intent_id": "pi_live_123",
                    }
                },
                "errors": [],
            }
        )

        self.assertEqual(
            stage["stage"],
            "paid_webhook_verified_waiting_for_bank_credit",
        )
        self.assertFalse(stage["goal_complete"])

    def test_classifies_bank_credit_as_goal_complete(self) -> None:
        stage = readiness.classify_revenue_stage(
            {
                "checks": {
                    "bank": {
                        "statement_date": "2026-07-03",
                        "credited_amount_jpy": 1,
                        "stripe_payout_id": "po_live_123",
                        "payout_arrival_date": "",
                        "bank_reference": "redacted statement line",
                    }
                },
                "errors": [],
            }
        )

        self.assertEqual(stage["stage"], "bank_credit_verified")
        self.assertTrue(stage["goal_complete"])


if __name__ == "__main__":
    unittest.main()
