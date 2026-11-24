#!/usr/bin/env python3
"""Tests for AI University RSS manifest, run reconciliation, and daily-report upsert."""
from __future__ import annotations

import pathlib
import re
import tempfile
import unittest

import ai_university_rss_manifest as manifest


REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
WORKFLOW_PATH = REPO_ROOT / ".github" / "workflows" / "ai-university-update.yml"


class AiUniversityRssManifestTest(unittest.TestCase):
    def test_manifest_is_unique_and_non_empty(self) -> None:
        ids = manifest.validate_manifest()
        self.assertEqual(len(ids), len(manifest.ACTIVE_RSS_PROVIDERS))
        self.assertEqual(len(manifest.ACTIVE_RSS_PROVIDERS), 75)

    def test_validate_run_accepts_reconciled_counts(self) -> None:
        total = len(manifest.ACTIVE_RSS_PROVIDERS)
        failed, skipped = manifest.validate_run_counts(
            manifest_total=total,
            succeeded=total - 3,
            failed=1,
            skipped=2,
            failed_providers_raw="openai",
            skipped_providers_raw="google microsoft",
            run_key="123456-1",
        )
        self.assertEqual(failed, ["openai"])
        self.assertEqual(skipped, ["google", "microsoft"])

    def test_validate_run_fails_closed_on_contradictions(self) -> None:
        total = len(manifest.ACTIVE_RSS_PROVIDERS)
        cases = [
            # Wrong manifest total (e.g., stale hard-coded 14)
            dict(
                manifest_total=14,
                succeeded=10,
                failed=2,
                skipped=2,
                failed_providers_raw="openai google",
                skipped_providers_raw="microsoft amazon",
                run_key="123456-1",
            ),
            # Sum exceeds / contradicts manifest total (e.g., 18/9)
            dict(
                manifest_total=total,
                succeeded=total,
                failed=1,
                skipped=0,
                failed_providers_raw="openai",
                skipped_providers_raw="",
                run_key="123456-1",
            ),
            # Negative value
            dict(
                manifest_total=total,
                succeeded=total + 1,
                failed=-1,
                skipped=0,
                failed_providers_raw="",
                skipped_providers_raw="",
                run_key="123456-1",
            ),
            # Missing run key
            dict(
                manifest_total=total,
                succeeded=total,
                failed=0,
                skipped=0,
                failed_providers_raw="",
                skipped_providers_raw="",
                run_key=" ",
            ),
            # List length mismatch
            dict(
                manifest_total=total,
                succeeded=total - 1,
                failed=1,
                skipped=0,
                failed_providers_raw="",
                skipped_providers_raw="",
                run_key="123456-1",
            ),
        ]
        for kwargs in cases:
            with self.assertRaises(ValueError, msg=f"Should fail closed: {kwargs}"):
                manifest.validate_run_counts(**kwargs)

    def test_upsert_report_consolidates_legacy_duplicates_and_updates_in_place(self) -> None:
        total = len(manifest.ACTIVE_RSS_PROVIDERS)
        with tempfile.TemporaryDirectory() as tmpdir:
            report_path = pathlib.Path(tmpdir) / "2026-11-23.md"
            report_path.write_text(
                "\n".join(
                    [
                        "# 自分株式会社 日次レポート 2026-11-23",
                        "",
                        "## AI大学コンテンツ更新 (ai-university-update)",
                        "",
                        "- 更新成功: 18/9",
                        "",
                        "## 別セクション",
                        "",
                        "- keep me",
                        "",
                        "## AI大学コンテンツ更新 (ai-university-update)",
                        "",
                        "- 更新成功: 12/9",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

            first = manifest.upsert_daily_report(
                report_path=report_path,
                date_label="2026-11-23",
                run_key="999001-1",
                manifest_total=total,
                succeeded=total - 1,
                failed=0,
                skipped=1,
                failed_providers_raw="",
                skipped_providers_raw="openai",
            )
            self.assertEqual(first.count(manifest.SECTION_HEADING), 1)
            self.assertEqual(first.count("run-key:999001-1"), 1)
            self.assertIn("- keep me", first)
            self.assertIn(f"{total - 1}/{total}", first)
            self.assertNotIn("/9", first)

            second = manifest.upsert_daily_report(
                report_path=report_path,
                date_label="2026-11-23",
                run_key="999002-1",
                manifest_total=total,
                succeeded=total,
                failed=0,
                skipped=0,
                failed_providers_raw="",
                skipped_providers_raw="",
            )
            self.assertEqual(second.count(manifest.SECTION_HEADING), 1)
            self.assertEqual(second.count("run-key:999002-1"), 1)
            self.assertNotIn("run-key:999001-1", second)
            self.assertIn(f"{total}/{total}", second)

    def test_workflow_contains_no_stale_hardcoded_denominators_or_legacy_loops(self) -> None:
        workflow_text = WORKFLOW_PATH.read_text(encoding="utf-8")
        self.assertNotIn("/9", workflow_text)
        self.assertNotIn("TOTAL_PROVIDERS=14", workflow_text)
        self.assertIsNone(
            re.search(r'^\s*upsert_provider\s+"[a-z0-9_]+"', workflow_text, re.MULTILINE)
        )
        self.assertIn("ai_university_rss_manifest.py validate-run", workflow_text)
        self.assertIn("ai_university_rss_manifest.py upsert-report", workflow_text)


if __name__ == "__main__":
    unittest.main()
