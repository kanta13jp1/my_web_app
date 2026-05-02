#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from wbs_sync_aggregate import aggregate_from_files, aggregate_responses


class WbsSyncAggregateTest(unittest.TestCase):
    def test_aggregates_repair_audit_fields(self) -> None:
        repaired_task = {
            "task_id": "task-1270-a",
            "github_issue_number": 1270,
            "reason": "closed issue was still in progress",
        }
        aggregate = aggregate_responses(
            [
                {
                    "success": True,
                    "issue_count": 2,
                    "created": 1,
                    "updated": 1,
                    "completed_from_closed_issues": 1,
                    "duplicate_wbs_closed": 0,
                    "stale_wbs_repaired": 1,
                    "wbs_task_scan_count": 10,
                    "skipped": 0,
                    "repaired_wbs_tasks": [repaired_task],
                },
                {
                    "success": True,
                    "issue_count": "3",
                    "created": 0,
                    "updated": 2,
                    "completed_from_closed_issues": 0,
                    "duplicate_wbs_closed": 1,
                    "stale_wbs_repaired": 2,
                    "wbs_task_scan_count": 12,
                    "skipped": 1,
                    "repaired_wbs_tasks": [
                        repaired_task,
                        {
                            "task_id": "task-1272-b",
                            "github_issue_number": 1272,
                            "reason": "duplicate closed issue row",
                        },
                    ],
                },
            ]
        )

        self.assertTrue(aggregate["success"])
        self.assertEqual(aggregate["issue_count"], 5)
        self.assertEqual(aggregate["stale_wbs_repaired"], 3)
        self.assertEqual(aggregate["wbs_task_scan_count"], 22)
        self.assertEqual(len(aggregate["repaired_wbs_tasks"]), 2)
        self.assertEqual(aggregate["repaired_wbs_tasks"][0]["task_id"], "task-1270-a")

    def test_failed_batches_mark_aggregate_unsuccessful(self) -> None:
        aggregate = aggregate_responses(
            [{"success": True, "issue_count": 1}],
            [{"batch": 2, "http_code": "504"}],
        )

        self.assertFalse(aggregate["success"])
        self.assertEqual(aggregate["batch_failures"], [{"batch": 2, "http_code": "504"}])

    def test_reads_workflow_temp_files(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            base = Path(tmp_dir)
            responses = base / "responses.jsonl"
            failures = base / "failures.tsv"
            responses.write_text(
                "\n".join(
                    [
                        json.dumps(
                            {
                                "success": True,
                                "issue_count": 1,
                                "stale_wbs_repaired": 1,
                                "wbs_task_scan_count": 4,
                                "repaired_wbs_tasks": [{"task_id": "task-1"}],
                            }
                        ),
                        "",
                    ]
                ),
                encoding="utf-8",
            )
            failures.write_text("", encoding="utf-8")

            aggregate = aggregate_from_files(responses, failures)

        self.assertEqual(aggregate["stale_wbs_repaired"], 1)
        self.assertEqual(aggregate["wbs_task_scan_count"], 4)
        self.assertEqual(aggregate["repaired_wbs_tasks"], [{"task_id": "task-1"}])


if __name__ == "__main__":
    unittest.main()
