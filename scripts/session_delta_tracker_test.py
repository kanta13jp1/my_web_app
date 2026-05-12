#!/usr/bin/env python3
"""Unit tests for session_delta_tracker.py."""

from __future__ import annotations

import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

import session_delta_tracker as tracker


NOW = datetime(2026, 5, 9, 0, 0, tzinfo=timezone.utc)


class SessionDeltaTrackerTest(unittest.TestCase):
    def test_median_reclaim_uses_last_seven_days(self) -> None:
        rows = [
            tracker.DeltaRow(NOW - timedelta(days=8), "s1", "end", 70.0, 1.0, None),
            tracker.DeltaRow(NOW - timedelta(days=1), "s2", "end", 71.0, 100.0, None),
            tracker.DeltaRow(NOW, "s3", "end", 72.0, 300.0, None),
        ]

        self.assertEqual(tracker.median_reclaim_mb(rows, NOW), 200.0)

    def test_warnings_cover_low_median_and_free_space(self) -> None:
        warnings = tracker.warnings_for(
            current_free_gb=29.0,
            reclaim_median_mb=50.0,
            free_delta_7d_gb=-4.0,
            median_floor_mb=100.0,
            free_floor_gb=30.0,
            seven_day_delta_floor_gb=-3.0,
        )

        self.assertEqual(len(warnings), 3)

    def test_append_and_read_rows_round_trip(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "session-delta.csv"
            tracker.append_row(
                path,
                {
                    "ts": NOW.isoformat().replace("+00:00", "Z"),
                    "session_id": "abc",
                    "phase": "start",
                    "c_free_gb": "80.00",
                    "reclaim_mb_session": "",
                    "reclaim_mb_7d_median": "",
                },
            )
            rows = tracker.read_rows(path)

        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].session_id, "abc")
        self.assertEqual(rows[0].c_free_gb, 80.0)


if __name__ == "__main__":
    unittest.main()
