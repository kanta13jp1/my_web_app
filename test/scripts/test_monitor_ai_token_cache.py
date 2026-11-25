#!/usr/bin/env python3
"""Offline unit tests for scripts/monitor_ai_token_cache.py (#2733)."""

from __future__ import annotations

from pathlib import Path
import sys
import unittest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import monitor_ai_token_cache as mod  # noqa: E402


class MonitorAiTokenCacheTest(unittest.TestCase):
    def test_baseline_report_aggregates_tools_and_cache_reuse(self) -> None:
        report = mod.evaluate_token_cache_report()
        self.assertEqual(report["total_requests"], 6)
        self.assertEqual(report["total_usage_units"], 5110)
        self.assertGreater(report["cache_reuse_ratio"], 0.75)
        self.assertFalse(report["alert_triggered"])

    def test_alerts_on_low_cache_reuse_ratio(self) -> None:
        low_cache = [
            {
                mod.KEY_CACHE_READ: 100,
                mod.KEY_CACHE_WRITE: 900,
                mod.KEY_UNCACHED_INPUT: 2000,
                "cache_hit": False,
                "net_savings_usd": -0.01,
            }
        ]
        report = mod.evaluate_token_cache_report(
            cache_rows=low_cache,
            min_cache_reuse_ratio=0.5,
        )
        self.assertTrue(report["alert_triggered"])
        self.assertTrue(
            any("cache_reuse_ratio_below_threshold" in a for a in report["alerts"])
        )

    def test_detects_prefix_timestamp_and_eager_tool_bloat(self) -> None:
        diag = mod.diagnose_prefix_stability(
            "Build 2026-11-25T10:20:30Z system rules",
            tool_count=24,
            use_tool_search=False,
            breakpoint_count=0,
        )
        self.assertEqual(diag["status"], "unstable")
        self.assertIn("dynamic_timestamp_in_prefix", diag["warnings"])
        self.assertIn("eager_tool_bloat_without_tool_search", diag["warnings"])
        self.assertIn("missing_cache_breakpoint", diag["warnings"])

    def test_specialization_matrix_doc_exists_with_required_tiers(self) -> None:
        doc = (REPO_ROOT / "docs" / "AI_MODEL_SPECIALIZATION_EVALUATION.md").read_text(
            encoding="utf-8"
        )
        self.assertIn("search_tool_discovery", doc)
        self.assertIn("bounded_execution", doc)
        self.assertIn("complex_reasoning", doc)
        self.assertIn("Tool Search Tool", doc)


if __name__ == "__main__":
    unittest.main()
