#!/usr/bin/env python3
from __future__ import annotations

import unittest

from scripts.notion_migration_cloud_audit import collect_audit, render_summary


class FakeClient:
    def __init__(self, responses: dict[str, list[dict[str, object]]]) -> None:
        self.responses = responses

    def rows(
        self,
        resource: str,
        query: list[tuple[str, str]],
    ) -> list[dict[str, object]]:
        del query
        return self.responses.get(resource, [])

    def all_rows(
        self,
        resource: str,
        query: list[tuple[str, str]],
        *,
        page_size: int = 1000,
    ) -> list[dict[str, object]]:
        del query, page_size
        return self.responses.get(resource, [])


def fixture(
    *,
    batch_status: str = "migrating",
    total: int = 10,
    imported: int = 4,
    verified: int = 2,
    ready: int = 0,
    deleted: int = 0,
    capability_verified: int = 3,
) -> dict[str, list[dict[str, object]]]:
    return {
        "notion_migration_batches": [
            {
                "id": "private-batch-id",
                "workspace_name": "must-not-leak",
                "status": batch_status,
                "created_at": "2026-08-30T00:00:00Z",
                "updated_at": "2026-08-30T01:00:00Z",
            }
        ],
        "notion_migration_batch_progress": [
            {
                "total_items": total,
                "imported_items": imported,
                "verified_items": verified,
                "deletion_ready_items": ready,
                "source_deleted_items": deleted,
                "failed_items": 1,
            }
        ],
        "notion_migration_capability_progress": [
            {
                "required_capabilities": 26,
                "verified_capabilities": capability_verified,
                "gap_capabilities": 4,
                "blocked_capabilities": 2,
            }
        ],
        "notion_migration_wbs_stage_progress": [
            {
                "staged_rows": 4705,
                "distinct_task_ids": 4530,
                "duplicate_rows": 175,
                "invalid_task_ids": 0,
                "staged_at": "2026-08-30T00:30:00Z",
            }
        ],
        "notion_migration_wbs_staging": [
            {
                "source_page_id": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                "task_id": "11111111-1111-4111-8111-111111111111",
                "title": "aggregate-only source",
                "instance": "codex",
                "status": "in_progress",
                "progress": 40,
                "deadline": "2026-09-01",
                "source_updated_at": "2026-08-30T01:00:00Z",
                "source_last_edited_at": "2026-08-30T02:00:00Z",
            }
        ],
        "wbs_tasks": [
            {
                "id": "11111111-1111-4111-8111-111111111111",
                "title": "aggregate-only source",
                "instance": "codex",
                "status": "in_progress",
                "progress": 40,
                "end_date": "2026-09-01",
                "updated_at": "2026-08-30T01:00:00Z",
                "category": "Development",
            }
        ],
        "notion_migration_vault_manifests": [
            {
                "status": "staged",
                "file_count": 100,
                "auto_stage_count": 80,
                "review_required_count": 15,
                "excluded_count": 5,
                "credential_candidate_count": 2,
                "unresolved_wikilink_occurrences": 7,
                "staged_entry_count": 95,
                "staged_at": "2026-08-30T00:45:00Z",
            }
        ],
    }


class NotionMigrationCloudAuditTest(unittest.TestCase):
    def test_incomplete_batch_keeps_destructive_gates_closed(self) -> None:
        report = collect_audit(FakeClient(fixture()))

        self.assertEqual(report["items"]["total"], 10)
        self.assertFalse(report["gates"]["source_deletion_open"])
        self.assertFalse(report["gates"]["subscription_cancellation_open"])
        self.assertIn("Import the next safe staged unit", report["next_action"])

    def test_deletion_ready_items_open_only_source_deletion_gate(self) -> None:
        report = collect_audit(
            FakeClient(
                fixture(
                    imported=10,
                    verified=10,
                    ready=3,
                    deleted=7,
                    capability_verified=26,
                )
            )
        )

        self.assertTrue(report["gates"]["source_deletion_open"])
        self.assertFalse(report["gates"]["subscription_cancellation_open"])

    def test_completed_batch_opens_cancellation_gate(self) -> None:
        report = collect_audit(
            FakeClient(
                fixture(
                    batch_status="completed",
                    imported=10,
                    verified=10,
                    deleted=10,
                    capability_verified=26,
                )
            )
        )

        self.assertTrue(report["gates"]["subscription_cancellation_open"])

    def test_summary_contains_only_aggregate_evidence(self) -> None:
        report = collect_audit(FakeClient(fixture()))
        summary = render_summary(report)

        self.assertIn("棚卸し 10", summary)
        self.assertIn("4705", summary)
        self.assertEqual(report["wbs_import_plan"]["decisions"]["unchanged"], 1)
        self.assertIn("WBS cloud import plan", summary)
        self.assertNotIn("private-batch-id", summary)
        self.assertNotIn("must-not-leak", summary)
        self.assertNotIn("aggregate-only source", summary)
        self.assertNotIn("aaaaaaaa-aaaa", summary)

    def test_no_batch_is_safe_and_actionable(self) -> None:
        report = collect_audit(FakeClient({}))
        summary = render_summary(report)

        self.assertIsNone(report["batch"])
        self.assertFalse(report["gates"]["source_deletion_open"])
        self.assertIn("No active migration batch", summary)


if __name__ == "__main__":
    unittest.main()
