#!/usr/bin/env python3
from __future__ import annotations

import unittest

from scripts.notion_migration_cloud_audit import (
    AuditError,
    _wbs_resolution_plan,
    collect_audit,
    render_summary,
)


class FakeClient:
    def __init__(self, responses: dict[str, list[dict[str, object]]]) -> None:
        self.responses = responses
        self.calls: list[
            tuple[str, str, list[tuple[str, str]]]
        ] = []

    def rows(
        self,
        resource: str,
        query: list[tuple[str, str]],
    ) -> list[dict[str, object]]:
        self.calls.append(("rows", resource, query))
        return self.responses.get(resource, [])

    def all_rows(
        self,
        resource: str,
        query: list[tuple[str, str]],
        *,
        page_size: int = 1000,
    ) -> list[dict[str, object]]:
        del page_size
        self.calls.append(("all_rows", resource, query))
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
    item_statuses = (
        ["source_deleted"] * deleted
        + ["ready_for_source_deletion"] * ready
        + ["verified"] * (verified - ready - deleted)
        + ["imported"] * (imported - verified)
        + ["inventoried"] * (total - imported)
    )
    if total > imported:
        item_statuses[imported] = "failed"
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
                "failed_items": 1 if total > imported else 0,
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
        "notion_migration_items": [
            {
                "source_kind": "page",
                "status": status,
                "source_id": "must-not-leak",
                "title": "must-not-leak",
            }
            for status in item_statuses
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
        client = FakeClient(fixture())
        report = collect_audit(client)
        summary = render_summary(report)

        self.assertIn("棚卸し 10", summary)
        self.assertIn("4705", summary)
        self.assertEqual(report["wbs_import_plan"]["decisions"]["unchanged"], 1)
        self.assertEqual(report["wbs_resolution_plan"]["automatic"]["total"], 1)
        self.assertEqual(report["wbs_resolution_plan"]["human_review"]["total"], 0)
        self.assertFalse(report["wbs_resolution_plan"]["writes_authorized"])
        self.assertIn("WBS cloud import plan", summary)
        self.assertIn("WBS resolution lanes", summary)
        self.assertNotIn("private-batch-id", summary)
        self.assertNotIn("must-not-leak", summary)
        self.assertNotIn("aggregate-only source", summary)
        self.assertNotIn("aaaaaaaa-aaaa", summary)
        self.assertEqual(
            report["item_breakdown"]["by_source_kind"]["page"],
            {
                "total": 10,
                "imported_or_later": 4,
                "remaining": 6,
                "failed": 1,
                "skipped": 0,
            },
        )
        item_calls = [
            query
            for method, resource, query in client.calls
            if method == "all_rows" and resource == "notion_migration_items"
        ]
        self.assertEqual(len(item_calls), 1)
        self.assertIn(("select", "source_kind,status"), item_calls[0])

    def test_resolution_plan_separates_automatic_and_human_lanes(self) -> None:
        resolution = _wbs_resolution_plan(
            {
                "safe_logical_groups": 3,
                "blocked_logical_groups": 2,
                "decisions": {
                    "insert": 0,
                    "update_from_notion": 0,
                    "unchanged": 2,
                    "site_newer_preserved": 1,
                    "manual_timestamp_conflict": 0,
                    "identity_collision": 0,
                    "invalid_fields": 0,
                    "conflicting_duplicate": 1,
                    "title_group_content_conflict": 1,
                },
            }
        )

        self.assertEqual(resolution["automatic"]["total"], 3)
        self.assertEqual(resolution["human_review"]["total"], 2)
        self.assertEqual(
            resolution["automatic"]["by_decision"]["site_newer_preserved"],
            1,
        )
        self.assertEqual(
            resolution["human_review"]["by_decision"]["conflicting_duplicate"],
            1,
        )
        self.assertFalse(resolution["writes_authorized"])

    def test_resolution_plan_rejects_inconsistent_counts(self) -> None:
        with self.assertRaisesRegex(
            AuditError,
            "WBS automatic decision count mismatch",
        ):
            _wbs_resolution_plan(
                {
                    "safe_logical_groups": 2,
                    "blocked_logical_groups": 0,
                    "decisions": {"unchanged": 1},
                }
            )

    def test_unknown_item_enum_is_rejected_without_echoing_value(self) -> None:
        responses = fixture(total=1, imported=0, verified=0)
        responses["notion_migration_items"] = [
            {"source_kind": "private-value", "status": "inventoried"}
        ]

        with self.assertRaisesRegex(
            AuditError,
            "invalid migration item source kind",
        ):
            collect_audit(FakeClient(responses))

    def test_no_batch_is_safe_and_actionable(self) -> None:
        report = collect_audit(FakeClient({}))
        summary = render_summary(report)

        self.assertIsNone(report["batch"])
        self.assertFalse(report["gates"]["source_deletion_open"])
        self.assertIn("No active migration batch", summary)


if __name__ == "__main__":
    unittest.main()
