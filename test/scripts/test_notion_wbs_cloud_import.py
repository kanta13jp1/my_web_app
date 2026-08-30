#!/usr/bin/env python3
from __future__ import annotations

import io
import json
import unittest
import urllib.error
from copy import deepcopy
from typing import Any

from scripts.notion_wbs_cloud_import import (
    ImportError,
    _safe_postgrest_code,
    run_import,
)
from scripts.notion_wbs_import_plan import build_wbs_import_plan


TASK_ID = "11111111-1111-4111-8111-111111111111"
PAGE_IDS = [
    "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
]
BATCH_ID = "22222222-2222-4222-8222-222222222222"
USER_ID = "33333333-3333-4333-8333-333333333333"


def staged(page_id: str) -> dict[str, Any]:
    return {
        "source_page_id": page_id,
        "task_id": TASK_ID,
        "title": "private staged title",
        "instance": "codex",
        "status": "in_progress",
        "progress": 40,
        "deadline": "2026-09-01",
        "source_updated_at": "2026-08-30T03:00:00Z",
        "source_last_edited_at": "2026-08-30T03:00:00Z",
    }


def item(index: int, page_id: str, *, status: str = "inventoried") -> dict[str, Any]:
    return {
        "id": f"44444444-4444-4444-8444-44444444444{index}",
        "batch_id": BATCH_ID,
        "user_id": USER_ID,
        "source_id": f"page:{page_id}",
        "parent_source_id": "data_source:private",
        "source_kind": "page",
        "title": "private item title",
        "source_path": "private/path",
        "status": status,
        "destination_kind": None,
        "destination_id": None,
        "source_hash": None,
        "destination_hash": None,
        "source_updated_at": "2026-08-30T03:00:00Z",
        "imported_at": None,
        "verified_at": None,
        "deletion_authorized_at": None,
        "source_deleted_at": None,
        "last_error": None,
        "metadata": {},
        "created_at": "2026-08-30T01:00:00Z",
        "updated_at": "2026-08-30T01:00:00Z",
    }


class FakeClient:
    def __init__(
        self,
        stage_rows: list[dict[str, Any]],
        item_rows: list[dict[str, Any]],
        site_rows: list[dict[str, Any]] | None = None,
    ) -> None:
        self.stage_rows = deepcopy(stage_rows)
        self.item_rows = deepcopy(item_rows)
        self.site_rows = deepcopy(site_rows or [])
        self.check_rows: list[dict[str, Any]] = []
        self.upserts: list[tuple[str, list[dict[str, Any]], str]] = []

    def rows(
        self,
        resource: str,
        _query: list[tuple[str, str]],
        **_kwargs: object,
    ) -> list[dict[str, Any]]:
        if resource != "notion_migration_batches":
            raise AssertionError(resource)
        return [
            {
                "id": BATCH_ID,
                "user_id": USER_ID,
                "status": "inventory",
                "created_at": "2026-08-30T01:00:00Z",
            }
        ]

    def all_rows(
        self,
        resource: str,
        _query: list[tuple[str, str]],
        **_kwargs: object,
    ) -> list[dict[str, Any]]:
        if resource == "notion_migration_wbs_staging":
            return deepcopy(self.stage_rows)
        if resource == "wbs_tasks":
            return deepcopy(self.site_rows)
        if resource == "notion_migration_items":
            return deepcopy(self.item_rows)
        if resource == "notion_migration_checks":
            return deepcopy(self.check_rows)
        raise AssertionError(resource)

    def upsert(
        self,
        resource: str,
        rows: list[dict[str, Any]],
        *,
        on_conflict: str,
    ) -> None:
        copied = deepcopy(rows)
        self.upserts.append((resource, copied, on_conflict))
        if resource == "wbs_tasks":
            for row in copied:
                existing = next(
                    (
                        current
                        for current in self.site_rows
                        if current["id"] == row["id"]
                    ),
                    None,
                )
                if existing is None:
                    self.site_rows.append(
                        {
                            **row,
                            "updated_at": "2026-08-30T04:00:00Z",
                        }
                    )
                else:
                    existing.update(row)
                    existing["updated_at"] = "2026-08-30T04:00:00Z"
            return
        if resource == "notion_migration_items":
            for row in copied:
                existing = next(
                    current
                    for current in self.item_rows
                    if current["id"] == row["id"]
                )
                existing.update(row)
            return
        if resource == "notion_migration_checks":
            for row in copied:
                existing = next(
                    (
                        current
                        for current in self.check_rows
                        if current["item_id"] == row["item_id"]
                        and current["check_key"] == row["check_key"]
                    ),
                    None,
                )
                if existing is None:
                    self.check_rows.append(row)
                else:
                    existing.update(row)
            return
        raise AssertionError(resource)


class NotionWbsCloudImportTest(unittest.TestCase):
    def test_postgrest_error_exposes_only_a_safe_code(self) -> None:
        error = urllib.error.HTTPError(
            "https://example.invalid",
            400,
            "bad request",
            {},
            io.BytesIO(
                b'{"code":"23514","message":"private row content"}'
            ),
        )

        self.assertEqual(_safe_postgrest_code(error), "23514")

    def setUp(self) -> None:
        self.stage_rows = [staged(PAGE_IDS[0]), staged(PAGE_IDS[1])]
        self.item_rows = [
            item(0, PAGE_IDS[0]),
            item(1, PAGE_IDS[1]),
        ]

    def test_plan_is_content_free_and_never_mutates(self) -> None:
        client = FakeClient(self.stage_rows, self.item_rows)

        report = run_import(
            client,
            mode="plan",
            expected_plan_sha256="",
            offset=0,
            limit=100,
        )
        encoded = json.dumps(report)

        self.assertEqual(client.upserts, [])
        self.assertTrue(report["safe_apply_gate_open"])
        self.assertEqual(report["selected_logical_groups"], 1)
        self.assertEqual(report["selected_source_items"], 2)
        self.assertNotIn("private staged title", encoded)
        self.assertNotIn(PAGE_IDS[0], encoded)
        self.assertFalse(report["source_deletion_attempted"])

    def test_apply_requires_the_current_digest_before_any_write(self) -> None:
        client = FakeClient(self.stage_rows, self.item_rows)

        with self.assertRaisesRegex(ImportError, "does not match"):
            run_import(
                client,
                mode="apply",
                expected_plan_sha256="0" * 64,
                offset=0,
                limit=100,
            )

        self.assertEqual(client.upserts, [])

    def test_apply_imports_exact_duplicates_idempotently_in_bulk(self) -> None:
        client = FakeClient(self.stage_rows, self.item_rows)
        digest = build_wbs_import_plan(self.stage_rows, [])["plan_sha256"]

        report = run_import(
            client,
            mode="apply",
            expected_plan_sha256=digest,
            offset=0,
            limit=100,
        )

        self.assertEqual(report["mutations"]["wbs_rows"], 1)
        self.assertEqual(report["mutations"]["items_imported_now"], 2)
        self.assertEqual(report["mutations"]["checks_upserted"], 14)
        self.assertTrue(all(row["status"] == "imported" for row in client.item_rows))
        self.assertEqual(len(client.site_rows), 1)
        self.assertEqual(len(client.check_rows), 14)
        self.assertFalse(report["source_deletion_attempted"])
        encoded = json.dumps(report)
        self.assertNotIn("private staged title", encoded)
        self.assertNotIn(TASK_ID, encoded)

        refreshed_digest = build_wbs_import_plan(
            self.stage_rows,
            client.site_rows,
        )["plan_sha256"]
        rerun = run_import(
            client,
            mode="apply",
            expected_plan_sha256=refreshed_digest,
            offset=0,
            limit=100,
        )
        self.assertEqual(rerun["mutations"]["wbs_rows"], 0)
        self.assertEqual(rerun["mutations"]["items_imported_now"], 0)

    def test_batch_size_cannot_exceed_one_hundred(self) -> None:
        client = FakeClient(self.stage_rows, self.item_rows)

        with self.assertRaisesRegex(ImportError, "between 1 and 100"):
            run_import(
                client,
                mode="plan",
                expected_plan_sha256="",
                offset=0,
                limit=101,
            )

        self.assertEqual(client.upserts, [])

    def test_missing_inventory_mapping_closes_safe_gate(self) -> None:
        client = FakeClient(self.stage_rows, self.item_rows[:1])

        report = run_import(
            client,
            mode="plan",
            expected_plan_sha256="",
            offset=0,
            limit=100,
        )

        self.assertEqual(report["missing_source_items"], 1)
        self.assertFalse(report["safe_apply_gate_open"])
        self.assertEqual(client.upserts, [])


if __name__ == "__main__":
    unittest.main()
