#!/usr/bin/env python3
"""Unit tests for scripts/check_notion_benchmark_doc.py (#2815)."""

from __future__ import annotations

import datetime as dt
import sys
import tempfile
import unittest
from pathlib import Path

_SCRIPTS_DIR = Path(__file__).resolve().parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from check_notion_benchmark_doc import validate_notion_benchmark_doc  # noqa: E402

REPO_ROOT = _SCRIPTS_DIR.parent


class NotionBenchmarkDocTests(unittest.TestCase):
    def test_repo_notion_benchmark_doc_passes(self) -> None:
        doc_path = REPO_ROOT / "docs" / "COMPETITIVE_BENCHMARK_NOTION_3_4.md"
        res = validate_notion_benchmark_doc(
            doc_path,
            today=dt.date(2026, 11, 26),
        )
        self.assertTrue(res.ok, msg=f"Errors: {res.errors}")
        self.assertTrue(res.has_primary_urls)
        self.assertTrue(res.has_comparison_table)
        self.assertTrue(res.has_differentiation_section)

    def test_missing_comparison_table_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "BENCH.md"
            doc.write_text(
                "---\nlast_reviewed: 2026-11-26\n---\n"
                "https://www.notion.com/releases\n差別化\n未確認\n",
                encoding="utf-8",
            )
            res = validate_notion_benchmark_doc(
                doc,
                today=dt.date(2026, 11, 26),
            )
        self.assertFalse(res.ok)
        self.assertFalse(res.has_comparison_table)

    def test_missing_review_date_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            doc = Path(tmp) / "NO_DATE.md"
            doc.write_text(
                "https://www.notion.com/product/ai\n| Notion | personal_dashboard_page.dart |\n差別化\n未確認\n",
                encoding="utf-8",
            )
            res = validate_notion_benchmark_doc(doc)
        self.assertFalse(res.ok)
        self.assertIsNone(res.last_reviewed)


if __name__ == "__main__":
    unittest.main()
