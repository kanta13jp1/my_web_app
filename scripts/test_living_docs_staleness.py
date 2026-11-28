#!/usr/bin/env python3
"""Unit tests for scripts/check_living_docs_staleness.py (#2793)."""

from __future__ import annotations

import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from check_living_docs_staleness import (  # noqa: E402
    check_dart_doc_readiness,
    evaluate_living_docs,
)


class LivingDocsStalenessTests(unittest.TestCase):
    def test_fresh_doc_passes_without_issue_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "ARCH.md"
            doc.write_text(
                "---\nlast_reviewed: 2026-11-20\n---\n# Architecture\n",
                encoding="utf-8",
            )
            report = evaluate_living_docs(
                doc_paths=[doc],
                today=dt.date(2026, 11, 26),
                max_age_days=90,
            )

        self.assertFalse(report.has_stale)
        self.assertEqual(report.doc_records[0].status, "fresh")
        self.assertEqual(report.doc_records[0].age_days, 6)
        self.assertIsNone(report.dry_run_issue_payload)

    def test_stale_doc_generates_dry_run_issue_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "OLD_SPEC.md"
            doc.write_text(
                "---\nlast_reviewed: 2026-06-01\n---\n# Old Spec\n",
                encoding="utf-8",
            )
            report = evaluate_living_docs(
                doc_paths=[doc],
                today=dt.date(2026, 11, 26),
                max_age_days=90,
            )

        self.assertTrue(report.has_stale)
        self.assertEqual(report.doc_records[0].status, "stale")
        self.assertGreater(report.doc_records[0].age_days or 0, 90)
        self.assertIsNotNone(report.dry_run_issue_payload)
        assert report.dry_run_issue_payload is not None
        self.assertIn("living-docs", report.dry_run_issue_payload["labels"])

    def test_missing_review_date_flagged_when_required(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "NO_DATE.md"
            doc.write_text("# No Frontmatter\n", encoding="utf-8")
            report = evaluate_living_docs(
                doc_paths=[doc],
                today=dt.date(2026, 11, 26),
                require_frontmatter=True,
            )

        self.assertTrue(report.has_stale)
        self.assertEqual(report.doc_records[0].status, "missing_review_date")

    def test_dart_doc_readiness_counts_documented_public_types(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            dart = Path(tmp) / "sample_service.dart"
            dart.write_text(
                "/// Documented public service.\n"
                "class PublicService {}\n"
                "class UndocumentedHelper {}\n"
                "class _PrivateIgnored {}\n",
                encoding="utf-8",
            )
            rec = check_dart_doc_readiness(dart)

        self.assertEqual(rec.public_types, 2)
        self.assertEqual(rec.documented_types, 1)
        self.assertEqual(rec.coverage_ratio, 0.5)


if __name__ == "__main__":
    unittest.main()
