#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class DailyRevenueMetricsContractTest(unittest.TestCase):
    def test_service_role_digest_adds_aggregate_only_billing_metrics(self) -> None:
        source = (
            ROOT / "supabase/functions/schedule-hub/index.ts"
        ).read_text(encoding="utf-8")

        self.assertIn("const billingPromise = serviceRoleRequest", source)
        self.assertIn('.from("billing_subscriptions")', source)
        self.assertIn('.select("tier, status")', source)
        self.assertIn("summarizeDailyBillingMetrics(billingRes.data ?? [])", source)
        self.assertIn("...(billingMetrics ?? {})", source)
        self.assertNotIn('.select("user_id, tier, status")', source)

    def test_daily_report_persists_and_renders_zero_safe_revenue(self) -> None:
        workflow = (
            ROOT / ".github/workflows/daily-report.yml"
        ).read_text(encoding="utf-8")

        self.assertIn(".digest.paid.total // 0", workflow)
        self.assertIn(".digest.revenue.mrrYen // 0", workflow)
        self.assertIn("課金ユーザー%s人、MRR ¥%s", workflow)
        self.assertIn('"${PAID_CUSTOMERS:-0}" "${MRR_YEN:-0}"', workflow)
        self.assertIn("収益進捗入り投稿草案 (確認後に投稿)", workflow)


if __name__ == "__main__":
    unittest.main()
