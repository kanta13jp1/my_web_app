#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PLAN = (ROOT / "docs" / "SUPABASE_CAPACITY_PLAN.md").read_text(encoding="utf-8")
MONITORING = (ROOT / "docs" / "PRODUCTION_MONITORING_RUNBOOK.md").read_text(
    encoding="utf-8"
)
CI = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")


class SupabaseCapacityPlanTest(unittest.TestCase):
    def test_free_baseline_and_primary_sources_are_explicit(self) -> None:
        for marker in (
            "Nano, shared CPU, up to 0.5 GB memory",
            "500 MB per project",
            "1 GB included",
            "60 direct database connections",
            "200 pooler clients",
            "https://supabase.com/docs/guides/platform/compute-and-disk",
            "https://supabase.com/docs/guides/platform/database-size",
            "https://supabase.com/docs/guides/monitoring-and-debugging/reports",
        ):
            self.assertIn(marker, PLAN)

    def test_capacity_thresholds_are_staged_before_the_free_quota(self) -> None:
        for marker in (
            "70% (350 MB)",
            "80% (400 MB)",
            "90% (450 MB)",
            "100% (500 MB)",
            "30 days or less",
            "14 days or less",
            "7 days or less",
        ):
            self.assertIn(marker, PLAN)

    def test_cleanup_contract_is_bounded_and_approval_gated(self) -> None:
        for marker in (
            "An unset retention period means",
            "deletion is blocked",
            "read-only dry-run",
            "verified backup/export and restore test",
            "at most 1,000 rows and 30 seconds per transaction",
            "10,000 rows per run",
            "saved cursor",
            "VACUUM FULL",
            "explicit database-owner approval",
        ):
            self.assertIn(marker, PLAN)

    def test_scale_change_cannot_be_automatically_authorized(self) -> None:
        for marker in (
            "budget owner",
            "Spend Cap",
            "A compute-size change can incur downtime",
            "may not purchase, resize, or change billing controls",
            "Disk increases cannot be treated as automatically reversible",
        ):
            self.assertIn(marker, PLAN)

    def test_monitoring_runbook_and_ci_reference_the_contract(self) -> None:
        self.assertIn("SUPABASE_CAPACITY_PLAN.md", MONITORING)
        self.assertIn("python scripts/supabase_capacity_plan_test.py", CI)


if __name__ == "__main__":
    unittest.main()
