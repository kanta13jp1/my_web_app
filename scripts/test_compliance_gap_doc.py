#!/usr/bin/env python3
"""Unit tests for scripts/check_compliance_gap_doc.py (#2812)."""

from __future__ import annotations

import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from check_compliance_gap_doc import validate_compliance_gap_doc  # noqa: E402

REPO_ROOT = _SCRIPTS_DIR.parent


class ComplianceGapDocTests(unittest.TestCase):
    def test_repo_compliance_gap_doc_passes_validation(self) -> None:
        doc_path = REPO_ROOT / "docs" / "ENTERPRISE_COMPLIANCE_GAP_ANALYSIS.md"
        res = validate_compliance_gap_doc(
            doc_path,
            today=dt.date(2026, 11, 26),
        )
        self.assertTrue(res.ok, msg=f"Errors: {res.errors}")
        self.assertEqual(res.missing_frameworks, ())
        self.assertEqual(res.missing_providers, ())
        self.assertTrue(res.has_unverified_disclosure)

    def test_missing_framework_fails_validation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "GAP.md"
            doc.write_text(
                "---\nlast_reviewed: 2026-11-26\n---\n"
                "SOC2 Type II / Supabase / OpenAI / Anthropic / Google Cloud / 未確認\n",
                encoding="utf-8",
            )
            res = validate_compliance_gap_doc(
                doc,
                today=dt.date(2026, 11, 26),
            )
        self.assertFalse(res.ok)
        self.assertIn("HIPAA", res.missing_frameworks)
        self.assertIn("PCI DSS", res.missing_frameworks)

    def test_missing_review_date_fails_validation(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "NO_DATE.md"
            doc.write_text(
                "SOC2 Type II HIPAA PCI DSS Supabase OpenAI Anthropic Google Cloud 未確認\n",
                encoding="utf-8",
            )
            res = validate_compliance_gap_doc(doc)
        self.assertFalse(res.ok)
        self.assertIsNone(res.last_reviewed)


if __name__ == "__main__":
    unittest.main()
