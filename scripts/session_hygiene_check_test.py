#!/usr/bin/env python3
"""Unit tests for session_hygiene_check.py."""

from __future__ import annotations

import csv
import tempfile
import unittest
from pathlib import Path

import session_hygiene_check as hygiene


class SessionHygieneCheckTest(unittest.TestCase):
    def run_sample(self, free_gb: float, ram_pct: float | None = None, apply: bool = False, force: bool = False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            log_path = root / "memory" / "session_hygiene_log.csv"
            args = hygiene.parse_args(
                [
                    "--root",
                    str(root),
                    "--log-path",
                    str(log_path),
                    "--sample-free-gb",
                    str(free_gb),
                    "--mode",
                    "test",
                    *([] if ram_pct is None else ["--sample-ram-pct", str(ram_pct)]),
                    *(["--apply"] if apply else []),
                    *(["--force"] if force else []),
                ]
            )
            result = hygiene.run_hygiene(args)
            with log_path.open(encoding="utf-8") as handle:
                rows = list(csv.DictReader(handle))
            return result, rows

    def test_ok_below_warning_thresholds(self):
        result, rows = self.run_sample(40.0, 30.0)
        self.assertEqual("ok", result.severity)
        self.assertFalse(result.should_auto_apply)
        self.assertEqual("ok", rows[0]["severity"])

    def test_warn_does_not_apply_without_auto_threshold(self):
        result, rows = self.run_sample(20.0, 86.0, apply=True)
        self.assertEqual("warn", result.severity)
        self.assertFalse(result.should_auto_apply)
        self.assertFalse(result.applied)
        self.assertEqual("False", rows[0]["applied"])

    def test_auto_threshold_marks_apply_candidate(self):
        result, rows = self.run_sample(14.9, 91.0)
        self.assertEqual("auto", result.severity)
        self.assertTrue(result.should_auto_apply)
        self.assertFalse(result.applied)
        self.assertIn("C free 14.90GB", rows[0]["reasons"])

    def test_force_apply_runs_git_gc_even_without_auto(self):
        result, _rows = self.run_sample(40.0, 30.0, apply=True, force=True)
        self.assertEqual("ok", result.severity)
        self.assertTrue(result.should_auto_apply)
        self.assertTrue(result.applied)
        self.assertIn(result.git_gc.status, {"success", "failed", "missing"})


if __name__ == "__main__":
    unittest.main()
