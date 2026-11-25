#!/usr/bin/env python3
"""Unit tests for scripts/check_dual_write_markers.py (#2774)."""

from __future__ import annotations

from datetime import date
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_dual_write_markers as checker


class CheckDualWriteMarkersTest(unittest.TestCase):
    def test_valid_markers_across_languages(self) -> None:
        today = date(2026, 11, 26)
        samples = [
            "// DUAL-WRITE TRANSITION: issue=#2774 sunset=2026-12-10 read-failsafe=legacy_col",
            "-- DUAL-WRITE TRANSITION: issue: #2774 sunset: 2026-11-26 read-failsafe: metadata.old_key",
            "# DUAL-WRITE TRANSITION: issue=#1234 sunset=2026-12-01 read-failsafe=old_table/v1",
        ]
        for idx, line in enumerate(samples, start=1):
            finding = checker.parse_marker_line("sample.dart", idx, line, today)
            self.assertEqual(finding.status, "active", line)
            self.assertEqual(finding.errors, ())
            self.assertIsNotNone(finding.issue)
            self.assertIsNotNone(finding.sunset)
            self.assertIsNotNone(finding.read_failsafe)

    def test_missing_metadata_marks_invalid(self) -> None:
        today = date(2026, 11, 26)
        finding = checker.parse_marker_line(
            "lib/foo.dart",
            12,
            "// DUAL-WRITE TRANSITION: temporary fallback",
            today,
        )
        self.assertEqual(finding.status, "invalid")
        self.assertIn("missing issue=#<num>", finding.errors)
        self.assertIn("missing sunset=YYYY-MM-DD", finding.errors)
        self.assertIn("missing read-failsafe=<legacy-source>", finding.errors)

    def test_invalid_calendar_date_marks_invalid(self) -> None:
        today = date(2026, 11, 26)
        finding = checker.parse_marker_line(
            "supabase/migrations/001.sql",
            5,
            "-- DUAL-WRITE TRANSITION: issue=#999 sunset=2026-02-30 read-failsafe=old_col",
            today,
        )
        self.assertEqual(finding.status, "invalid")
        self.assertIn("invalid sunset date: 2026-02-30", finding.errors)

    def test_expired_marker_detected_on_past_sunset(self) -> None:
        today = date(2026, 11, 26)
        finding = checker.parse_marker_line(
            "supabase/functions/app-hub/index.ts",
            44,
            "// DUAL-WRITE TRANSITION: issue=#2774 sunset=2026-11-25 read-failsafe=old_field",
            today,
        )
        self.assertEqual(finding.status, "expired")
        self.assertEqual(finding.errors, ())

    def test_scan_repository_skips_docs_and_flags_strict_expired(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "docs").mkdir()
            (root / "docs" / "DUAL_WRITE_TRANSITION_STANDARD.md").write_text(
                "DUAL-WRITE TRANSITION: invalid doc example\n",
                encoding="utf-8",
            )
            (root / "lib").mkdir()
            (root / "lib" / "sample.dart").write_text(
                "// DUAL-WRITE TRANSITION: issue=#2774 sunset=2026-11-20 read-failsafe=old_v1\n",
                encoding="utf-8",
            )
            findings = checker.scan_repository(root, today=date(2026, 11, 26))
            self.assertEqual(len(findings), 1)
            self.assertEqual(findings[0].status, "expired")

            rc_default = checker.main(["--root", str(root), "--today", "2026-11-26"])
            self.assertEqual(rc_default, 0)

            rc_strict = checker.main(
                ["--root", str(root), "--today", "2026-11-26", "--strict-expired"]
            )
            self.assertEqual(rc_strict, 1)

    def test_cli_invalid_marker_fails_and_json_output(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "scripts").mkdir()
            (root / "scripts" / "demo.py").write_text(
                "# DUAL-WRITE TRANSITION: issue=#10 read-failsafe=old\n",
                encoding="utf-8",
            )
            rc = checker.main(["--root", str(root), "--today", "2026-11-26"])
            self.assertEqual(rc, 1)

            rc_bad_today = checker.main(["--root", str(root), "--today", "bad-date"])
            self.assertEqual(rc_bad_today, 2)

    def test_json_serialization(self) -> None:
        finding = checker.parse_marker_line(
            "lib/a.dart",
            1,
            "// DUAL-WRITE TRANSITION: issue=#2774 sunset=2026-12-10 read-failsafe=old_col",
            date(2026, 11, 26),
        )
        encoded = json.dumps(finding.to_dict(), ensure_ascii=False)
        decoded = json.loads(encoded)
        self.assertEqual(decoded["status"], "active")
        self.assertEqual(decoded["issue"], "#2774")


if __name__ == "__main__":
    unittest.main()
