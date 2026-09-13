#!/usr/bin/env python3
"""Create a content-free Notion migration progress audit from Supabase."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from scripts.notion_wbs_import_plan import build_wbs_import_plan


class AuditError(RuntimeError):
    """Safe audit failure that never includes response data or credentials."""


MIGRATION_ITEM_SOURCE_KINDS = frozenset(
    {
        "workspace",
        "teamspace",
        "page",
        "database",
        "data_source",
        "view",
        "block",
        "comment",
        "attachment",
        "automation",
        "form",
        "user",
    }
)
MIGRATION_ITEM_STATUSES = frozenset(
    {
        "inventoried",
        "queued",
        "exporting",
        "imported",
        "verifying",
        "verified",
        "ready_for_source_deletion",
        "source_deleted",
        "failed",
        "skipped",
    }
)
IMPORTED_OR_LATER_STATUSES = frozenset(
    {
        "imported",
        "verifying",
        "verified",
        "ready_for_source_deletion",
        "source_deleted",
    }
)


def _integer(row: dict[str, Any], key: str) -> int:
    value = row.get(key, 0)
    if value is None:
        return 0
    try:
        return int(value)
    except (TypeError, ValueError) as exc:
        raise AuditError(f"invalid aggregate field: {key}") from exc


class SupabaseAuditClient:
    def __init__(self, base_url: str, service_role_key: str) -> None:
        if not base_url.startswith("https://"):
            raise AuditError("SUPABASE_URL must use HTTPS")
        if not service_role_key:
            raise AuditError("SUPABASE_SERVICE_ROLE_KEY is missing")
        self._rest_url = f"{base_url.rstrip('/')}/rest/v1"
        self._headers = {
            "Accept": "application/json",
            "Authorization": f"Bearer {service_role_key}",
            "apikey": service_role_key,
        }

    def rows(
        self,
        resource: str,
        query: list[tuple[str, str]],
        *,
        range_start: int | None = None,
        range_end: int | None = None,
    ) -> list[dict[str, Any]]:
        encoded = urllib.parse.urlencode(query)
        headers = dict(self._headers)
        if range_start is not None and range_end is not None:
            headers["Range"] = f"{range_start}-{range_end}"
        request = urllib.request.Request(
            f"{self._rest_url}/{resource}?{encoded}",
            headers=headers,
            method="GET",
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                payload = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            raise AuditError(
                f"Supabase returned HTTP {exc.code} for {resource}"
            ) from None
        except urllib.error.URLError as exc:
            raise AuditError(f"Supabase request failed for {resource}") from exc
        except json.JSONDecodeError as exc:
            raise AuditError(
                f"Supabase returned invalid JSON for {resource}"
            ) from exc

        if not isinstance(payload, list) or any(
            not isinstance(row, dict) for row in payload
        ):
            raise AuditError(f"Supabase returned an invalid row set for {resource}")
        return payload

    def all_rows(
        self,
        resource: str,
        query: list[tuple[str, str]],
        *,
        page_size: int = 1000,
    ) -> list[dict[str, Any]]:
        result: list[dict[str, Any]] = []
        for start in range(0, 100000, page_size):
            page = self.rows(
                resource,
                query,
                range_start=start,
                range_end=start + page_size - 1,
            )
            result.extend(page)
            if len(page) < page_size:
                return result
        raise AuditError(f"row pagination limit exceeded for {resource}")


def _exactly_one(
    rows: list[dict[str, Any]],
    resource: str,
) -> dict[str, Any]:
    if len(rows) != 1:
        raise AuditError(f"expected one aggregate row from {resource}")
    return rows[0]


def _migration_item_breakdown(
    rows: list[dict[str, Any]],
    *,
    expected_total: int,
    expected_imported: int,
) -> dict[str, Any]:
    if len(rows) != expected_total:
        raise AuditError("migration item count does not match aggregate total")

    status_counts = {status: 0 for status in sorted(MIGRATION_ITEM_STATUSES)}
    source_counts: dict[str, dict[str, int]] = {}
    for row in rows:
        source_kind = str(row.get("source_kind") or "")
        status = str(row.get("status") or "")
        if source_kind not in MIGRATION_ITEM_SOURCE_KINDS:
            raise AuditError("invalid migration item source kind")
        if status not in MIGRATION_ITEM_STATUSES:
            raise AuditError("invalid migration item status")

        status_counts[status] += 1
        counts = source_counts.setdefault(
            source_kind,
            {
                "total": 0,
                "imported_or_later": 0,
                "remaining": 0,
                "failed": 0,
                "skipped": 0,
            },
        )
        counts["total"] += 1
        if status in IMPORTED_OR_LATER_STATUSES:
            counts["imported_or_later"] += 1
        else:
            counts["remaining"] += 1
        if status == "failed":
            counts["failed"] += 1
        if status == "skipped":
            counts["skipped"] += 1

    imported_or_later = sum(
        counts["imported_or_later"] for counts in source_counts.values()
    )
    if imported_or_later != expected_imported:
        raise AuditError("migration item count does not match imported aggregate")

    return {
        "status_counts": status_counts,
        "by_source_kind": {
            source_kind: source_counts[source_kind]
            for source_kind in sorted(source_counts)
        },
    }


def collect_audit(client: SupabaseAuditClient) -> dict[str, Any]:
    batches = client.rows(
        "notion_migration_batches",
        [
            ("select", "id,status,created_at,updated_at"),
            ("archived_at", "is.null"),
            ("order", "created_at.desc"),
            ("limit", "1"),
        ],
    )
    generated_at = datetime.now(timezone.utc).isoformat()
    if not batches:
        return {
            "schema_version": 1,
            "generated_at": generated_at,
            "batch": None,
            "gates": {
                "source_deletion_open": False,
                "subscription_cancellation_open": False,
            },
            "next_action": "Create an owner-scoped migration batch and inventory.",
        }

    batch = batches[0]
    batch_id = str(batch.get("id", ""))
    if not batch_id:
        raise AuditError("latest migration batch has no id")

    progress = _exactly_one(
        client.rows(
            "notion_migration_batch_progress",
            [
                (
                    "select",
                    "total_items,imported_items,verified_items,"
                    "deletion_ready_items,source_deleted_items,failed_items",
                ),
                ("batch_id", f"eq.{batch_id}"),
                ("limit", "1"),
            ],
        ),
        "notion_migration_batch_progress",
    )
    capabilities = _exactly_one(
        client.rows(
            "notion_migration_capability_progress",
            [
                (
                    "select",
                    "required_capabilities,verified_capabilities,"
                    "gap_capabilities,blocked_capabilities",
                ),
                ("batch_id", f"eq.{batch_id}"),
                ("limit", "1"),
            ],
        ),
        "notion_migration_capability_progress",
    )
    wbs = _exactly_one(
        client.rows(
            "notion_migration_wbs_stage_progress",
            [
                (
                    "select",
                    "staged_rows,distinct_task_ids,duplicate_rows,"
                    "invalid_task_ids,staged_at",
                ),
                ("batch_id", f"eq.{batch_id}"),
                ("limit", "1"),
            ],
        ),
        "notion_migration_wbs_stage_progress",
    )
    total = _integer(progress, "total_items")
    imported = _integer(progress, "imported_items")
    migration_item_rows = client.all_rows(
        "notion_migration_items",
        [
            ("select", "source_kind,status"),
            ("batch_id", f"eq.{batch_id}"),
            ("order", "source_kind.asc,status.asc"),
        ],
    )
    item_breakdown = _migration_item_breakdown(
        migration_item_rows,
        expected_total=total,
        expected_imported=imported,
    )
    vault_rows = client.rows(
        "notion_migration_vault_manifests",
        [
            (
                "select",
                "status,file_count,auto_stage_count,review_required_count,"
                "excluded_count,credential_candidate_count,"
                "unresolved_wikilink_occurrences,staged_entry_count,staged_at",
            ),
            ("batch_id", f"eq.{batch_id}"),
            ("order", "created_at.desc"),
            ("limit", "1"),
        ],
    )
    vault = vault_rows[0] if vault_rows else None
    staged_wbs_rows = client.all_rows(
        "notion_migration_wbs_staging",
        [
            (
                "select",
                "source_page_id,task_id,title,instance,status,progress,"
                "deadline,source_updated_at,source_last_edited_at",
            ),
            ("batch_id", f"eq.{batch_id}"),
            ("is_current", "eq.true"),
            ("order", "task_id.asc,source_page_id.asc"),
        ],
    )
    site_wbs_rows = client.all_rows(
        "wbs_tasks",
        [
            (
                "select",
                "id,title,instance,status,progress,end_date,updated_at,category",
            ),
            ("order", "id.asc"),
        ],
    )
    wbs_import_plan = build_wbs_import_plan(staged_wbs_rows, site_wbs_rows)

    verified = _integer(progress, "verified_items")
    deletion_ready = _integer(progress, "deletion_ready_items")
    deleted = _integer(progress, "source_deleted_items")
    required = _integer(capabilities, "required_capabilities")
    capability_verified = _integer(capabilities, "verified_capabilities")
    batch_status = str(batch.get("status", "unknown"))

    source_deletion_open = deletion_ready > 0
    subscription_cancellation_open = (
        total > 0
        and deleted == total
        and required > 0
        and capability_verified == required
        and batch_status == "completed"
    )

    if total == 0:
        next_action = "Continue the Notion inventory until the batch has items."
    elif imported < total:
        next_action = (
            "Import the next safe staged unit; source deletion remains disabled."
        )
    elif verified < total:
        next_action = "Run all seven evidence checks for every imported item."
    elif deletion_ready > 0:
        next_action = (
            "Only owner-authorized deletion-ready items may be deleted at source."
        )
    elif deleted < total:
        next_action = (
            "Record explicit owner authorization before any source deletion."
        )
    elif capability_verified < required:
        next_action = "Close and verify every required Notion capability gap."
    elif batch_status != "completed":
        next_action = "Complete the guarded batch after all database gates pass."
    else:
        next_action = "All cancellation gates are open; confirm billing separately."

    return {
        "schema_version": 1,
        "generated_at": generated_at,
        "batch": {
            "status": batch_status,
            "created_at": batch.get("created_at"),
            "updated_at": batch.get("updated_at"),
        },
        "items": {
            "total": total,
            "imported": imported,
            "verified": verified,
            "deletion_ready": deletion_ready,
            "source_deleted": deleted,
            "failed": _integer(progress, "failed_items"),
        },
        "item_breakdown": item_breakdown,
        "capabilities": {
            "required": required,
            "verified": capability_verified,
            "gap": _integer(capabilities, "gap_capabilities"),
            "blocked": _integer(capabilities, "blocked_capabilities"),
        },
        "wbs_stage": {
            "rows": _integer(wbs, "staged_rows"),
            "distinct_task_ids": _integer(wbs, "distinct_task_ids"),
            "duplicate_rows": _integer(wbs, "duplicate_rows"),
            "invalid_task_ids": _integer(wbs, "invalid_task_ids"),
            "staged_at": wbs.get("staged_at"),
        },
        "wbs_import_plan": wbs_import_plan,
        "vault_manifest": (
            None
            if vault is None
            else {
                "status": vault.get("status"),
                "files": _integer(vault, "file_count"),
                "auto_stage": _integer(vault, "auto_stage_count"),
                "review_required": _integer(vault, "review_required_count"),
                "excluded": _integer(vault, "excluded_count"),
                "credential_candidates": _integer(
                    vault, "credential_candidate_count"
                ),
                "unresolved_wikilinks": _integer(
                    vault, "unresolved_wikilink_occurrences"
                ),
                "staged_entries": _integer(vault, "staged_entry_count"),
                "staged_at": vault.get("staged_at"),
            }
        ),
        "gates": {
            "source_deletion_open": source_deletion_open,
            "subscription_cancellation_open": subscription_cancellation_open,
        },
        "next_action": next_action,
    }


def render_summary(report: dict[str, Any]) -> str:
    lines = [
        "## Notion migration cloud audit",
        "",
        "This run is read-only. It did not import, delete, cancel, or expose content.",
        "",
    ]
    batch = report.get("batch")
    if batch is None:
        lines.extend(
            [
                "No active migration batch was found.",
                "",
                f"Next: {report['next_action']}",
            ]
        )
        return "\n".join(lines) + "\n"

    items = report["items"]
    item_breakdown = report["item_breakdown"]
    capabilities = report["capabilities"]
    wbs = report["wbs_stage"]
    wbs_plan = report["wbs_import_plan"]
    vault = report["vault_manifest"]
    gates = report["gates"]
    lines.extend(
        [
            "### Session progress",
            "",
            "<pre>",
            f"棚卸し {items['total']}",
            f"  → 取込済み {items['imported']}",
            f"  → 7項目照合済み {items['verified']}",
            f"  → 削除可能 {items['deletion_ready']}",
            f"  → Notion削除済み {items['source_deleted']}",
            (
                "  → サブスク解約ゲート "
                + ("OPEN" if gates["subscription_cancellation_open"] else "CLOSED")
            ),
            "</pre>",
            "",
            "### Inventory composition",
            "",
            (
                "| source kind | total | imported or later | remaining | "
                "failed | skipped |"
            ),
            "| --- | ---: | ---: | ---: | ---: | ---: |",
            *[
                (
                    f"| {source_kind} | {counts['total']} | "
                    f"{counts['imported_or_later']} | {counts['remaining']} | "
                    f"{counts['failed']} | {counts['skipped']} |"
                )
                for source_kind, counts in item_breakdown[
                    "by_source_kind"
                ].items()
            ],
            "",
            "| Guard | Value |",
            "| --- | ---: |",
            f"| batch status | {batch['status']} |",
            f"| failed items | {items['failed']} |",
            (
                "| required capabilities | "
                f"{capabilities['verified']} / {capabilities['required']} verified |"
            ),
            f"| capability gaps | {capabilities['gap']} |",
            f"| blocked capabilities | {capabilities['blocked']} |",
            (
                "| source deletion gate | "
                + ("OPEN" if gates["source_deletion_open"] else "CLOSED")
                + " |"
            ),
            (
                "| subscription cancellation gate | "
                + ("OPEN" if gates["subscription_cancellation_open"] else "CLOSED")
                + " |"
            ),
            "",
            "### WBS safe stage",
            "",
            "| staged rows | distinct IDs | duplicates | invalid IDs |",
            "| ---: | ---: | ---: | ---: |",
            (
                f"| {wbs['rows']} | {wbs['distinct_task_ids']} | "
                f"{wbs['duplicate_rows']} | {wbs['invalid_task_ids']} |"
            ),
            "",
            "### WBS cloud import plan",
            "",
            (
                "| canonical | logical | aliases | insert | update | "
                "unchanged | site newer | blockers |"
            ),
            "| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
            (
                f"| {wbs_plan['canonical_rows']} | "
                f"{wbs_plan['logical_rows']} | "
                f"{wbs_plan['identity_alias_rows']} | "
                f"{wbs_plan['decisions']['insert']} | "
                f"{wbs_plan['decisions']['update_from_notion']} | "
                f"{wbs_plan['decisions']['unchanged']} | "
                f"{wbs_plan['decisions']['site_newer_preserved']} | "
                f"{wbs_plan['blockers']} |"
            ),
            "",
            (
                "| duplicate groups | "
                f"{wbs_plan['exact_duplicate_groups']} exact / "
                f"{wbs_plan['conflicting_duplicate_groups']} conflicting |"
            ),
            (
                "| plan SHA-256 | "
                f"{wbs_plan['plan_sha256']} |"
            ),
            (
                "| apply gate | "
                + ("OPEN" if wbs_plan["apply_gate_open"] else "CLOSED")
                + " |"
            ),
        ]
    )
    if vault is not None:
        lines.extend(
            [
                "",
                "### Obsidian manifest stage",
                "",
                "| files | staged | review | excluded | credential candidates |",
                "| ---: | ---: | ---: | ---: | ---: |",
                (
                    f"| {vault['files']} | {vault['staged_entries']} | "
                    f"{vault['review_required']} | {vault['excluded']} | "
                    f"{vault['credential_candidates']} |"
                ),
            ]
        )
    lines.extend(["", f"Next: {report['next_action']}"])
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json-output", type=Path, required=True)
    parser.add_argument("--summary-output", type=Path, required=True)
    args = parser.parse_args(argv)

    try:
        client = SupabaseAuditClient(
            os.environ.get("SUPABASE_URL", ""),
            os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""),
        )
        report = collect_audit(client)
    except AuditError as exc:
        print(f"::error::Notion migration cloud audit failed: {exc}", file=sys.stderr)
        return 1

    args.json_output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    with args.summary_output.open("a", encoding="utf-8") as summary:
        summary.write(render_summary(report))
    print("Notion migration audit completed without content payloads.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
