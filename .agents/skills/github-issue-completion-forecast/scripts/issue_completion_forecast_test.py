#!/usr/bin/env python3
"""Unit tests for issue_completion_forecast.py."""

from __future__ import annotations

import unittest
from datetime import datetime, timezone

from issue_completion_forecast import calculate_forecast, format_markdown


class ForecastTest(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 8, 20, 6, 0, tzinfo=timezone.utc)

    def test_calculates_eta_from_30_day_throughput(self) -> None:
        forecast = calculate_forecast(
            repository="owner/repo",
            now=self.now,
            open_issues=90,
            closed_last_7_days=14,
            closed_last_30_days=30,
        )

        self.assertEqual(forecast.average_per_day_30_days, 1.0)
        self.assertEqual(forecast.estimated_days_remaining, 90.0)
        self.assertEqual(
            forecast.estimated_completion_at, "2026-11-18T15:00:00+09:00"
        )
        self.assertEqual(forecast.confidence, "medium")

    def test_withholds_eta_when_sample_is_too_small(self) -> None:
        forecast = calculate_forecast(
            repository="owner/repo",
            now=self.now,
            open_issues=90,
            closed_last_7_days=1,
            closed_last_30_days=2,
        )

        self.assertIsNone(forecast.estimated_days_remaining)
        self.assertIsNone(forecast.estimated_completion_at)
        self.assertEqual(forecast.confidence, "insufficient_data")
        self.assertIn("全件対応予定: 算出保留", format_markdown(forecast))

    def test_open_completed_issue_is_explicitly_included_in_count(self) -> None:
        forecast = calculate_forecast(
            repository="owner/repo",
            now=self.now,
            open_issues=12,
            closed_last_7_days=7,
            closed_last_30_days=30,
            completed_issue=7,
            completed_issue_state="OPEN",
        )

        report = format_markdown(forecast)
        self.assertIn("#7 OPEN（現在の件数に含む）", report)
        self.assertIn("現在のオープンIssue: 12件", report)

    def test_zero_open_issues_finishes_at_generation_time(self) -> None:
        forecast = calculate_forecast(
            repository="owner/repo",
            now=self.now,
            open_issues=0,
            closed_last_7_days=0,
            closed_last_30_days=0,
        )

        self.assertEqual(forecast.estimated_days_remaining, 0.0)
        self.assertEqual(
            forecast.estimated_completion_at, "2026-08-20T15:00:00+09:00"
        )
        self.assertEqual(forecast.confidence, "not_applicable")


if __name__ == "__main__":
    unittest.main()
