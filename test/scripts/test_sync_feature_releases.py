#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

import sync_feature_releases as sync


class SyncFeatureReleasesTest(unittest.TestCase):
    def test_builds_rows_only_from_feature_changes_and_dedupes(self) -> None:
        document = {
            "versions": [
                {
                    "version": "1.0.0",
                    "changes": [
                        {
                            "id": "pr-100",
                            "category": "feature",
                            "summary": "#100 新ダッシュボード追加 (2026-06-10)",
                            "mergedAt": "2026-06-10T01:00:00Z",
                            "links": [
                                {"url": "https://github.com/o/r/pull/100"},
                            ],
                        },
                        {
                            "id": "pr-100",
                            "category": "feature",
                            "summary": "#100 新ダッシュボード追加 (2026-06-10)",
                            "mergedAt": "2026-06-10T01:00:00Z",
                        },
                        {
                            "id": "pr-101",
                            "category": "fix",
                            "summary": "#101 bug fix",
                            "mergedAt": "2026-06-10T02:00:00Z",
                        },
                        {
                            "id": "pr-102",
                            "category": "feature",
                            "summary": "",
                            "mergedAt": "2026-06-10T03:00:00Z",
                        },
                        {
                            "id": "pr-103",
                            "category": "feature",
                            "summary": "#103 deps: bump the flutter-dependencies group",
                            "mergedAt": "2026-06-10T04:00:00Z",
                        },
                        {
                            "id": "pr-104",
                            "category": "feature",
                            "summary": "#104 ci(dependabot): pub group 週次CI失敗を解消",
                            "mergedAt": "2026-06-10T05:00:00Z",
                        },
                        {
                            "id": "pr-105",
                            "category": "feature",
                            "summary": "#105 docs(roadmap): part 216 spec ship",
                            "mergedAt": "2026-06-10T06:00:00Z",
                        },
                        {
                            "id": "pr-106",
                            "category": "feature",
                            "summary": "#106 [CI/CD自動最適化] concurrency 追加 2 件",
                            "mergedAt": "2026-06-10T07:00:00Z",
                        },
                    ],
                }
            ]
        }
        rows = sync.build_rows(document)
        self.assertEqual(len(rows), 1)
        row = rows[0]
        self.assertEqual(row["source_id"], "pr-100")
        self.assertEqual(row["feature_route"], "/release-notes")
        self.assertEqual(row["feature_label"], "新ダッシュボード追加")
        self.assertEqual(row["released_at"], "2026-06-10T01:00:00Z")
        self.assertEqual(row["category"], "feature")
        self.assertIn("https://github.com/o/r/pull/100", row["description"])

    def test_clean_label_truncates_long_summaries(self) -> None:
        label = sync.clean_label("#1 " + "あ" * 200 + " (2026-06-13)")
        self.assertLessEqual(len(label), sync.LABEL_MAX_LEN)
        self.assertTrue(label.endswith("…"))


if __name__ == "__main__":
    unittest.main()
