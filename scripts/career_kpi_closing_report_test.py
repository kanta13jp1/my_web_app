#!/usr/bin/env python3
"""Unit tests for career_kpi_closing_report.py (#2772)."""

from __future__ import annotations

import datetime as dt
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import career_kpi_closing_report as target


class CareerKpiClosingReportTest(unittest.TestCase):
    def test_is_month_end_handles_standard_and_leap_months(self) -> None:
        self.assertTrue(target.is_month_end(dt.date(2026, 4, 30)))
        self.assertFalse(target.is_month_end(dt.date(2026, 4, 29)))
        self.assertTrue(target.is_month_end(dt.date(2026, 2, 28)))
        self.assertFalse(target.is_month_end(dt.date(2028, 2, 28)))
        self.assertTrue(target.is_month_end(dt.date(2028, 2, 29)))

    def test_compute_closing_report_is_deterministic(self) -> None:
        items = [
            {
                "month_key": "2026-11",
                "annual_goal": "AIプロダクト品質向上",
                "metric_name": "テスト通過率",
                "target_value": 100,
                "actual_value": 50,
                "unit": "%",
                "reflection": "半分到達",
                "next_action": "残り50%を来週片付ける",
            },
            {
                "month_key": "2026-11",
                "annual_goal": "AIプロダクト品質向上",
                "metric_name": "PR完了数",
                "target_value": 4,
                "actual_value": 4,
                "unit": "件",
            },
            {
                "month_key": "2026-10",
                "annual_goal": "別月",
                "metric_name": "除外項目",
                "target_value": 1,
                "actual_value": 1,
            },
        ]
        first = target.compute_closing_report(
            items,
            "2026-11",
            generated_at="2026-11-30T14:00:00Z",
        )
        second = target.compute_closing_report(
            items,
            "2026-11",
            generated_at="2026-11-30T14:00:00Z",
        )

        self.assertEqual(first["total_metrics"], 2)
        self.assertEqual(first["completed_metrics"], 1)
        self.assertEqual(first["average_progress_percent"], 75)
        self.assertEqual(first["checksum"], second["checksum"])
        self.assertIn("# Career Monthly Close: 2026-11", first["markdown_report"])
        self.assertNotIn("除外項目", first["markdown_report"])

    def test_compute_closing_report_rejects_negative_values(self) -> None:
        with self.assertRaises(ValueError):
            target.compute_closing_report(
                [
                    {
                        "month_key": "2026-11",
                        "metric_name": "Bad KPI",
                        "target_value": -1,
                        "actual_value": 0,
                    }
                ],
                "2026-11",
            )

    def test_cli_self_check_and_month_end_skip(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            out_json = Path(tmpdir) / "close.json"
            out_md = Path(tmpdir) / "close.md"
            rc = target.main(
                [
                    "--month",
                    "2026-11",
                    "--today",
                    "2026-11-30",
                    "--check-month-end",
                    "--self-check",
                    "--output-json",
                    str(out_json),
                    "--output-md",
                    str(out_md),
                ]
            )
            self.assertEqual(rc, 0)
            payload = json.loads(out_json.read_text(encoding="utf-8"))
            self.assertEqual(payload["month_key"], "2026-11")
            self.assertEqual(len(payload["checksum"]), 16)
            self.assertTrue(out_md.exists())

            skip_rc = target.main(
                [
                    "--month",
                    "2026-11",
                    "--today",
                    "2026-11-29",
                    "--check-month-end",
                ]
            )
            self.assertEqual(skip_rc, 0)


if __name__ == "__main__":
    unittest.main()
