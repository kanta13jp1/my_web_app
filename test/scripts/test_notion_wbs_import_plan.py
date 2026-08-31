#!/usr/bin/env python3
from __future__ import annotations

import json
import unittest

from scripts.notion_wbs_import_plan import (
    build_wbs_import_plan,
    build_wbs_import_plan_details,
)


IDS = [
    "11111111-1111-4111-8111-111111111111",
    "22222222-2222-4222-8222-222222222222",
    "33333333-3333-4333-8333-333333333333",
    "44444444-4444-4444-8444-444444444444",
    "55555555-5555-4555-8555-555555555555",
]


def staged(
    task_id: str,
    title: str,
    *,
    source_page_id: str | None = None,
    progress: object = 0,
    source_updated_at: str = "2026-08-30T01:00:00Z",
    source_last_edited_at: str = "2026-08-30T02:00:00Z",
) -> dict[str, object]:
    return {
        "source_page_id": source_page_id or task_id,
        "task_id": task_id,
        "title": title,
        "instance": "codex",
        "status": "in_progress",
        "progress": progress,
        "deadline": "2026-09-01",
        "source_updated_at": source_updated_at,
        "source_last_edited_at": source_last_edited_at,
    }


def site(
    task_id: str,
    title: str,
    *,
    progress: object = 0,
    updated_at: str = "2026-08-30T01:00:00Z",
) -> dict[str, object]:
    return {
        "id": task_id,
        "title": title,
        "instance": "codex",
        "status": "in_progress",
        "progress": progress,
        "end_date": "2026-09-01",
        "updated_at": updated_at,
        "category": "Development",
    }


class NotionWbsImportPlanTest(unittest.TestCase):
    def test_exact_same_id_duplicate_collapses_and_keeps_private_sources(self) -> None:
        rows = [
            staged(
                IDS[0],
                "same",
                source_page_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            ),
            staged(
                IDS[0],
                "same",
                source_page_id="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            ),
        ]

        plan, actions = build_wbs_import_plan_details(rows, [])

        self.assertEqual(plan["canonical_rows"], 1)
        self.assertEqual(plan["logical_rows"], 1)
        self.assertEqual(plan["duplicate_rows"], 1)
        self.assertEqual(plan["exact_duplicate_groups"], 1)
        self.assertEqual(plan["decisions"]["insert"], 1)
        self.assertEqual(len(actions[0]["source_page_ids"]), 2)
        self.assertTrue(plan["apply_gate_open"])

    def test_conflicting_same_id_duplicate_blocks_apply(self) -> None:
        rows = [
            staged(
                IDS[0],
                "first",
                source_page_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
            ),
            staged(
                IDS[0],
                "second",
                source_page_id="bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
            ),
        ]

        plan = build_wbs_import_plan(rows, [])

        self.assertEqual(plan["conflicting_duplicate_groups"], 1)
        self.assertEqual(plan["decisions"]["conflicting_duplicate"], 1)
        self.assertFalse(plan["apply_gate_open"])

    def test_existing_rows_are_classified_by_content_and_time(self) -> None:
        stage_rows = [
            staged(IDS[0], "exact"),
            staged(
                IDS[1],
                "notion newer",
                source_updated_at="2026-08-30T03:00:00Z",
            ),
            staged(
                IDS[2],
                "notion older",
                source_updated_at="2026-08-30T01:00:00Z",
            ),
            staged(
                IDS[3],
                "equal time conflict",
                source_updated_at="2026-08-30T02:00:00Z",
            ),
        ]
        site_rows = [
            site(IDS[0], "exact"),
            site(IDS[1], "old site", updated_at="2026-08-30T02:00:00Z"),
            site(IDS[2], "new site", updated_at="2026-08-30T02:00:00Z"),
            site(IDS[3], "different", updated_at="2026-08-30T02:00:00Z"),
        ]

        plan = build_wbs_import_plan(stage_rows, site_rows)

        self.assertEqual(plan["decisions"]["unchanged"], 1)
        self.assertEqual(plan["decisions"]["update_from_notion"], 1)
        self.assertEqual(plan["decisions"]["site_newer_preserved"], 1)
        self.assertEqual(plan["decisions"]["manual_timestamp_conflict"], 1)
        self.assertFalse(plan["apply_gate_open"])

    def test_different_source_id_can_alias_existing_logical_task(self) -> None:
        plan = build_wbs_import_plan(
            [staged(IDS[1], "occupied")],
            [site(IDS[0], "occupied")],
        )

        self.assertEqual(plan["logical_rows"], 1)
        self.assertEqual(plan["identity_alias_rows"], 1)
        self.assertEqual(plan["decisions"]["unchanged"], 1)
        self.assertEqual(plan["identity_collisions"], 0)
        self.assertTrue(plan["apply_gate_open"])

    def test_existing_id_cannot_take_another_existing_title(self) -> None:
        plan = build_wbs_import_plan(
            [staged(IDS[1], "occupied")],
            [
                site(IDS[0], "occupied"),
                site(IDS[1], "different"),
            ],
        )

        self.assertEqual(plan["identity_collisions"], 1)
        self.assertEqual(plan["decisions"]["identity_collision"], 1)
        self.assertFalse(plan["apply_gate_open"])

    def test_exact_multi_id_sources_become_one_logical_insert(self) -> None:
        plan = build_wbs_import_plan(
            [
                staged(IDS[0], "same logical task"),
                staged(IDS[1], "same logical task"),
            ],
            [],
        )

        self.assertEqual(plan["canonical_rows"], 2)
        self.assertEqual(plan["logical_rows"], 1)
        self.assertEqual(plan["identity_alias_rows"], 1)
        self.assertEqual(plan["decisions"]["insert"], 1)
        self.assertTrue(plan["apply_gate_open"])

    def test_conflicting_multi_id_logical_group_blocks_apply(self) -> None:
        plan = build_wbs_import_plan(
            [
                staged(IDS[0], "same title", progress=10),
                staged(IDS[1], "same title", progress=20),
            ],
            [],
        )

        self.assertEqual(plan["title_group_content_conflicts"], 1)
        self.assertEqual(plan["decisions"]["title_group_content_conflict"], 1)
        self.assertFalse(plan["apply_gate_open"])

    def test_invalid_ids_and_database_fields_are_blockers(self) -> None:
        plan = build_wbs_import_plan(
            [
                staged("not-a-uuid", "invalid id"),
                staged(IDS[0], "", progress=101),
                {**staged(IDS[1], "bad instance"), "instance": "unknown-lane"},
                {**staged(IDS[2], "bad status"), "status": "cancelled"},
                {**staged(IDS[3], "bad deadline"), "deadline": "not-a-date"},
            ],
            [],
        )

        self.assertEqual(plan["invalid_task_id_rows"], 1)
        self.assertEqual(plan["invalid_field_rows"], 4)
        self.assertEqual(
            plan["validation_errors"],
            {
                "title": 1,
                "progress": 1,
                "instance": 1,
                "status": 1,
                "deadline": 1,
            },
        )
        self.assertFalse(plan["apply_gate_open"])

    def test_known_instance_alias_is_normalized_before_write(self) -> None:
        source = {**staged(IDS[0], "alias"), "instance": "Claude-Code"}

        plan, actions = build_wbs_import_plan_details([source], [])

        self.assertEqual(plan["validation_errors"]["instance"], 0)
        self.assertEqual(actions[0]["content"]["instance"], "claude")
        self.assertEqual(actions[0]["decision"], "insert")

    def test_public_result_never_contains_private_action_data(self) -> None:
        plan = build_wbs_import_plan(
            [
                staged(
                    IDS[0],
                    "sensitive title",
                    source_page_id="aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
                )
            ],
            [],
        )
        encoded = json.dumps(plan)

        self.assertNotIn("sensitive title", encoded)
        self.assertNotIn("aaaaaaaa-aaaa", encoded)
        self.assertRegex(plan["plan_sha256"], r"^[0-9a-f]{64}$")
        self.assertEqual(plan["safe_logical_groups"], 1)

    def test_digest_changes_when_source_content_changes(self) -> None:
        first = build_wbs_import_plan([staged(IDS[0], "first")], [])
        second = build_wbs_import_plan([staged(IDS[0], "second")], [])

        self.assertNotEqual(first["plan_sha256"], second["plan_sha256"])


if __name__ == "__main__":
    unittest.main()
