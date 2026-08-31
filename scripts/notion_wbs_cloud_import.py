#!/usr/bin/env python3
"""Plan or apply one content-free, bounded cloud batch of staged Notion WBS data."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from scripts.notion_wbs_import_plan import (
    SAFE_WBS_DECISIONS,
    build_wbs_import_plan_details,
    site_wbs_content,
    wbs_content_sha256,
)


IMPORTED_OR_LATER = frozenset(
    {
        "imported",
        "verifying",
        "verified",
        "ready_for_source_deletion",
        "source_deleted",
    }
)
CHECK_KEYS = (
    "backup",
    "content",
    "hierarchy",
    "properties",
    "attachments",
    "comments",
    "permissions",
)
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
NOTION_MIGRATION_API_VERSION = "2026-03-11"


class ImportError(RuntimeError):
    """Safe failure whose message contains no row content, IDs, or credentials."""


def _safe_postgrest_code(exc: urllib.error.HTTPError) -> str:
    try:
        payload = json.loads(exc.read().decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return "unknown"
    if not isinstance(payload, dict):
        return "unknown"
    code = str(payload.get("code") or "")
    return code if re.fullmatch(r"[A-Z0-9]{5,8}", code) else "unknown"


class SupabaseImportClient:
    def __init__(self, base_url: str, service_role_key: str) -> None:
        if not base_url.startswith("https://"):
            raise ImportError("SUPABASE_URL must use HTTPS")
        if not service_role_key:
            raise ImportError("SUPABASE_SERVICE_ROLE_KEY is missing")
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
            raise ImportError(
                f"Supabase returned HTTP {exc.code} for {resource}"
            ) from None
        except urllib.error.URLError as exc:
            raise ImportError(f"Supabase request failed for {resource}") from exc
        except json.JSONDecodeError as exc:
            raise ImportError(
                f"Supabase returned invalid JSON for {resource}"
            ) from exc
        if not isinstance(payload, list) or any(
            not isinstance(row, dict) for row in payload
        ):
            raise ImportError(f"Supabase returned invalid rows for {resource}")
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
        raise ImportError(f"row pagination limit exceeded for {resource}")

    def upsert(
        self,
        resource: str,
        rows: list[dict[str, Any]],
        *,
        on_conflict: str,
    ) -> None:
        if not rows:
            return
        encoded = urllib.parse.urlencode({"on_conflict": on_conflict})
        headers = {
            **self._headers,
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,missing=default,return=minimal",
        }
        request = urllib.request.Request(
            f"{self._rest_url}/{resource}?{encoded}",
            data=json.dumps(
                rows,
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            postgrest_code = _safe_postgrest_code(exc)
            raise ImportError(
                f"Supabase returned HTTP {exc.code} code {postgrest_code} "
                f"while writing {resource}"
            ) from None
        except urllib.error.URLError as exc:
            raise ImportError(f"Supabase write failed for {resource}") from exc

    def insert_ignore_duplicates(
        self,
        resource: str,
        rows: list[dict[str, Any]],
        *,
        on_conflict: str,
    ) -> None:
        if not rows:
            return
        encoded = urllib.parse.urlencode({"on_conflict": on_conflict})
        headers = {
            **self._headers,
            "Content-Type": "application/json",
            "Prefer": "resolution=ignore-duplicates,return=minimal",
        }
        request = urllib.request.Request(
            f"{self._rest_url}/{resource}?{encoded}",
            data=json.dumps(
                rows,
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            postgrest_code = _safe_postgrest_code(exc)
            raise ImportError(
                f"Supabase returned HTTP {exc.code} code {postgrest_code} "
                f"while inserting {resource}"
            ) from None
        except urllib.error.URLError as exc:
            raise ImportError(f"Supabase insert failed for {resource}") from exc

    def patch(
        self,
        resource: str,
        query: list[tuple[str, str]],
        values: dict[str, Any],
    ) -> None:
        encoded = urllib.parse.urlencode(query)
        headers = {
            **self._headers,
            "Content-Type": "application/json",
            "Prefer": "return=minimal",
        }
        request = urllib.request.Request(
            f"{self._rest_url}/{resource}?{encoded}",
            data=json.dumps(
                values,
                ensure_ascii=False,
                separators=(",", ":"),
            ).encode("utf-8"),
            headers=headers,
            method="PATCH",
        )
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                response.read()
        except urllib.error.HTTPError as exc:
            postgrest_code = _safe_postgrest_code(exc)
            raise ImportError(
                f"Supabase returned HTTP {exc.code} code {postgrest_code} "
                f"while patching {resource}"
            ) from None
        except urllib.error.URLError as exc:
            raise ImportError(f"Supabase patch failed for {resource}") from exc


def _latest_context(
    client: SupabaseImportClient,
) -> tuple[
    dict[str, Any],
    list[dict[str, Any]],
    list[dict[str, Any]],
    list[dict[str, Any]],
]:
    batches = client.rows(
        "notion_migration_batches",
        [
            ("select", "id,user_id,status,created_at"),
            ("archived_at", "is.null"),
            ("order", "created_at.desc"),
            ("limit", "1"),
        ],
    )
    if len(batches) != 1:
        raise ImportError("expected exactly one latest active migration batch")
    batch = batches[0]
    batch_id = str(batch.get("id") or "")
    if not batch_id:
        raise ImportError("latest batch is missing its identifier")

    staged_rows = client.all_rows(
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
    site_rows = client.all_rows(
        "wbs_tasks",
        [
            (
                "select",
                "id,title,instance,status,progress,end_date,updated_at,category",
            ),
            ("order", "id.asc"),
        ],
    )
    item_rows = client.all_rows(
        "notion_migration_items",
        [
            (
                "select",
                "id,batch_id,user_id,source_id,parent_source_id,source_kind,"
                "title,source_path,status,destination_kind,destination_id,"
                "source_hash,destination_hash,source_updated_at,imported_at,"
                "verified_at,deletion_authorized_at,source_deleted_at,"
                "last_error,metadata,created_at,updated_at",
            ),
            ("batch_id", f"eq.{batch_id}"),
            ("order", "source_id.asc"),
        ],
    )
    return batch, staged_rows, site_rows, item_rows


def _source_key(page_id: object) -> str:
    return f"page:{str(page_id or '').strip().lower()}"


def _parent_source_id(source_payload: object) -> str | None:
    if not isinstance(source_payload, dict):
        return None
    parent = source_payload.get("parent")
    if not isinstance(parent, dict):
        return None
    parent_type = str(parent.get("type") or "").strip()
    if parent_type == "workspace":
        return "workspace:root"
    raw_parent_id = str(parent.get(parent_type) or "").strip()
    if not parent_type or not raw_parent_id:
        return None
    parent_kind = parent_type.removesuffix("_id")
    value = f"{parent_kind}:{raw_parent_id}"
    return value if len(value) <= 512 else None


def _staged_inventory_row(
    batch: dict[str, Any],
    staged: dict[str, Any],
    *,
    now: str,
) -> dict[str, Any] | None:
    batch_id = str(batch.get("id") or "")
    batch_user_id = str(batch.get("user_id") or "")
    staged_user_id = str(staged.get("user_id") or "")
    page_id = str(staged.get("source_page_id") or "").strip().lower()
    source_payload = staged.get("source_payload")
    if (
        not batch_id
        or not batch_user_id
        or staged_user_id != batch_user_id
        or not page_id
        or len(page_id) > 507
        or not isinstance(source_payload, dict)
    ):
        return None
    properties = source_payload.get("properties")
    property_names = sorted(properties) if isinstance(properties, dict) else []
    title = str(staged.get("title") or "")[:1000]
    return {
        "batch_id": batch_id,
        "user_id": batch_user_id,
        "source_id": _source_key(page_id),
        "parent_source_id": _parent_source_id(source_payload),
        "source_kind": "page",
        "title": title,
        "source_path": title,
        "status": "inventoried",
        "source_updated_at": (
            staged.get("source_last_edited_at")
            or staged.get("source_updated_at")
        ),
        "metadata": {
            "notion_object": str(source_payload.get("object") or "page"),
            "notion_type": str(source_payload.get("type") or ""),
            "created_time": source_payload.get("created_time"),
            "in_trash": source_payload.get("in_trash") is True,
            "has_children": source_payload.get("has_children") is True,
            "property_names": property_names,
            "inventory_expanded": False,
            "inventory_seen_at": staged.get("staged_at") or now,
            "api_version": NOTION_MIGRATION_API_VERSION,
            "inventory_reconciled_from": "wbs_staging",
            "inventory_reconciled_at": now,
        },
    }


def _inventory_repair_rows(
    batch: dict[str, Any],
    actions: list[dict[str, Any]],
    items: list[dict[str, Any]],
    staged_rows: list[dict[str, Any]],
    *,
    now: str,
) -> tuple[list[dict[str, Any]], int]:
    existing_sources = {str(item.get("source_id") or "") for item in items}
    staged_by_source: dict[str, dict[str, Any]] = {}
    duplicate_staged_sources: set[str] = set()
    for staged in staged_rows:
        source = _source_key(staged.get("source_page_id"))
        if source in staged_by_source:
            duplicate_staged_sources.add(source)
        else:
            staged_by_source[source] = staged

    missing_sources: list[str] = []
    seen_missing: set[str] = set()
    conflicts = 0
    for action in actions:
        for page_id in action["source_page_ids"]:
            source = _source_key(page_id)
            if source in existing_sources:
                continue
            if source in seen_missing:
                conflicts += 1
                continue
            seen_missing.add(source)
            missing_sources.append(source)

    rows: list[dict[str, Any]] = []
    for source in missing_sources:
        if source in duplicate_staged_sources:
            conflicts += 1
            continue
        staged = staged_by_source.get(source)
        if staged is None:
            conflicts += 1
            continue
        row = _staged_inventory_row(batch, staged, now=now)
        if row is None or row["source_id"] != source:
            conflicts += 1
            continue
        rows.append(row)
    return rows, conflicts


def _missing_page_ids(
    actions: list[dict[str, Any]],
    items: list[dict[str, Any]],
) -> list[str]:
    existing_sources = {str(item.get("source_id") or "") for item in items}
    page_ids: list[str] = []
    seen_sources: set[str] = set()
    for action in actions:
        for page_id in action["source_page_ids"]:
            value = str(page_id or "").strip().lower()
            source = _source_key(value)
            if source in existing_sources or source in seen_sources:
                continue
            seen_sources.add(source)
            page_ids.append(value)
    return page_ids


def _repair_staging_rows(
    client: SupabaseImportClient,
    batch_id: str,
    page_ids: list[str],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for offset in range(0, len(page_ids), 50):
        chunk = page_ids[offset : offset + 50]
        if not chunk:
            continue
        rows.extend(
            client.all_rows(
                "notion_migration_wbs_staging",
                [
                    (
                        "select",
                        "user_id,source_page_id,title,source_updated_at,"
                        "source_last_edited_at,source_payload,staged_at",
                    ),
                    ("batch_id", f"eq.{batch_id}"),
                    ("is_current", "eq.true"),
                    ("source_page_id", f"in.({','.join(chunk)})"),
                    ("order", "source_page_id.asc"),
                ],
            )
        )
    return rows


def _selected_item_bindings(
    actions: list[dict[str, Any]],
    items: list[dict[str, Any]],
) -> tuple[list[tuple[dict[str, Any], dict[str, Any]]], int, int]:
    items_by_source = {str(item.get("source_id") or ""): item for item in items}
    bindings: list[tuple[dict[str, Any], dict[str, Any]]] = []
    missing = 0
    conflicts = 0
    seen_item_ids: set[str] = set()
    for action in actions:
        destination_id = str(action.get("destination_task_id") or "")
        if not destination_id:
            conflicts += 1
            continue
        for page_id in action["source_page_ids"]:
            item = items_by_source.get(_source_key(page_id))
            if item is None:
                missing += 1
                continue
            item_id = str(item.get("id") or "")
            if not item_id or item_id in seen_item_ids:
                conflicts += 1
                continue
            seen_item_ids.add(item_id)
            existing_kind = str(item.get("destination_kind") or "")
            existing_destination = str(item.get("destination_id") or "")
            if (
                (existing_kind and existing_kind != "wbs_task")
                or (
                    existing_destination
                    and existing_destination != destination_id
                )
            ):
                conflicts += 1
                continue
            bindings.append((action, item))
    return bindings, missing, conflicts


def _report_base(
    summary: dict[str, Any],
    selected: list[dict[str, Any]],
    bindings: list[tuple[dict[str, Any], dict[str, Any]]],
    missing: int,
    conflicts: int,
    repairable_missing: int,
    repair_conflicts: int,
    *,
    mode: str,
    offset: int,
    limit: int,
) -> dict[str, Any]:
    selected_decisions = {decision: 0 for decision in sorted(SAFE_WBS_DECISIONS)}
    for action in selected:
        selected_decisions[action["decision"]] += 1
    safe_total = int(summary["safe_logical_groups"])
    return {
        "schema_version": 1,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "mode": mode,
        "plan_sha256": summary["plan_sha256"],
        "safe_logical_groups": safe_total,
        "blocked_logical_groups": summary["blocked_logical_groups"],
        "validation_errors": summary["validation_errors"],
        "selected_offset": offset,
        "selected_limit": limit,
        "selected_logical_groups": len(selected),
        "selected_source_items": len(bindings),
        "missing_source_items": missing,
        "mapping_conflicts": conflicts,
        "repairable_missing_source_items": repairable_missing,
        "inventory_repair_conflicts": repair_conflicts,
        "inventory_repair_gate_open": (
            missing > 0
            and repairable_missing == missing
            and conflicts == 0
            and repair_conflicts == 0
        ),
        "selected_decisions": selected_decisions,
        "remaining_safe_groups_after_selection": max(
            0,
            safe_total - offset - len(selected),
        ),
        "safe_apply_gate_open": (
            len(selected) > 0 and missing == 0 and conflicts == 0
        ),
        "mutations": {
            "wbs_rows": 0,
            "items_imported_now": 0,
            "items_already_imported_or_later": 0,
            "checks_upserted": 0,
            "items_inventoried_now": 0,
        },
        "source_deletion_attempted": False,
    }


def _wbs_mutation_batches(
    selected: list[dict[str, Any]],
    site_rows: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    site_by_id = {str(row.get("id") or ""): row for row in site_rows}
    insert_rows: list[dict[str, Any]] = []
    update_rows: list[dict[str, Any]] = []
    for action in selected:
        if action["decision"] not in {"insert", "update_from_notion"}:
            continue
        destination_id = str(action["destination_task_id"])
        content = action["content"]
        values = {
            "title": content["title"],
            "instance": content["instance"],
            "status": content["status"],
            "progress": content["progress"],
            "end_date": content["deadline"],
        }
        if action["decision"] == "insert":
            existing = site_by_id.get(destination_id, {})
            insert_rows.append(
                {
                    "id": destination_id,
                    "category": str(existing.get("category") or "Notion移行"),
                    **values,
                }
            )
        else:
            update_rows.append({"id": destination_id, **values})
    return insert_rows, update_rows


def _verify_destinations(
    selected: list[dict[str, Any]],
    site_rows: list[dict[str, Any]],
) -> dict[str, tuple[str, bool]]:
    site_by_id = {str(row.get("id") or ""): row for row in site_rows}
    results: dict[str, tuple[str, bool]] = {}
    for action in selected:
        destination_id = str(action["destination_task_id"])
        destination = site_by_id.get(destination_id)
        if destination is None:
            raise ImportError("destination verification found a missing WBS row")
        source_hash = wbs_content_sha256(action["content"])
        destination_hash = wbs_content_sha256(site_wbs_content(destination))
        exact = source_hash == destination_hash
        if action["decision"] != "site_newer_preserved" and not exact:
            raise ImportError("destination content verification failed")
        results[destination_id] = (destination_hash, exact)
    return results


def _upsert_item_phase(
    client: SupabaseImportClient,
    bindings: list[tuple[dict[str, Any], dict[str, Any]]],
    source_statuses: frozenset[str],
    target_status: str,
    *,
    now: str,
    destination_results: dict[str, tuple[str, bool]] | None = None,
) -> int:
    payload: list[dict[str, Any]] = []
    for action, item in bindings:
        if str(item.get("status") or "") not in source_statuses:
            continue
        row = dict(item)
        row["status"] = target_status
        row["last_error"] = None
        if target_status == "imported":
            if destination_results is None:
                raise ImportError("destination evidence is unavailable")
            destination_id = str(action["destination_task_id"])
            destination_hash, _exact = destination_results[destination_id]
            source_hash = wbs_content_sha256(action["content"])
            metadata = row.get("metadata")
            if not isinstance(metadata, dict):
                metadata = {}
            row["destination_kind"] = "wbs_task"
            row["destination_id"] = destination_id
            row["source_hash"] = source_hash
            row["destination_hash"] = destination_hash
            row["imported_at"] = row.get("imported_at") or now
            row["metadata"] = {
                **metadata,
                "wbs_import": {
                    "plan_sha256": os.environ.get(
                        "EXPECTED_PLAN_SHA256",
                        "",
                    ),
                    "decision": action["decision"],
                    "applied_at": now,
                },
            }
        payload.append(row)
    client.upsert("notion_migration_items", payload, on_conflict="id")
    for _action, item in bindings:
        if str(item.get("status") or "") in source_statuses:
            item["status"] = target_status
    return len(payload)


def _upsert_checks(
    client: SupabaseImportClient,
    bindings: list[tuple[dict[str, Any], dict[str, Any]]],
    destination_results: dict[str, tuple[str, bool]],
    *,
    now: str,
) -> int:
    if not bindings:
        return 0
    item_ids = [str(item["id"]) for _action, item in bindings]
    checks = client.all_rows(
        "notion_migration_checks",
        [
            (
                "select",
                "item_id,check_key,status,source_count,destination_count,"
                "source_hash,destination_hash,checked_at,evidence_summary",
            ),
            ("item_id", f"in.({','.join(item_ids)})"),
        ],
    )
    existing = {
        (str(check.get("item_id") or ""), str(check.get("check_key") or "")): check
        for check in checks
    }
    payload: list[dict[str, Any]] = []
    for action, item in bindings:
        item_id = str(item["id"])
        user_id = str(item["user_id"])
        destination_id = str(action["destination_task_id"])
        destination_hash, exact = destination_results[destination_id]
        source_hash = wbs_content_sha256(action["content"])
        desired: dict[str, tuple[str, str]] = {
            "backup": (
                "passed",
                "Durable owner-scoped WBS staging evidence is retained.",
            ),
            "content": (
                "passed" if exact else "pending",
                (
                    "Normalized WBS content matches the destination."
                    if exact
                    else "The newer site value is preserved pending reconciliation."
                ),
            ),
            "hierarchy": (
                "passed",
                "The source data-source row maps to the WBS task collection.",
            ),
            "properties": (
                "passed" if exact else "pending",
                (
                    "Normalized WBS properties match the destination."
                    if exact
                    else "Property reconciliation remains pending."
                ),
            ),
            "attachments": (
                "pending",
                "Attachment verification has not run.",
            ),
            "comments": (
                "pending",
                "Comment verification has not run.",
            ),
            "permissions": (
                "pending",
                "Permission verification has not run.",
            ),
        }
        for check_key in CHECK_KEYS:
            prior = existing.get((item_id, check_key))
            status, evidence = desired[check_key]
            if prior is not None:
                if check_key in {"attachments", "comments", "permissions"}:
                    continue
                if str(prior.get("status") or "") == "passed" and status != "passed":
                    continue
            payload.append(
                {
                    "item_id": item_id,
                    "user_id": user_id,
                    "check_key": check_key,
                    "status": status,
                    "source_count": 1,
                    "destination_count": 1,
                    "source_hash": source_hash,
                    "destination_hash": destination_hash,
                    "checked_at": now if status == "passed" else None,
                    "evidence_summary": evidence,
                }
            )
    client.upsert(
        "notion_migration_checks",
        payload,
        on_conflict="item_id,check_key",
    )
    return len(payload)


def run_import(
    client: SupabaseImportClient,
    *,
    mode: str,
    expected_plan_sha256: str,
    offset: int,
    limit: int,
) -> dict[str, Any]:
    if mode not in {"plan", "repair_inventory", "apply"}:
        raise ImportError("mode must be plan, repair_inventory, or apply")
    if offset < 0:
        raise ImportError("safe offset must be non-negative")
    if not 1 <= limit <= 100:
        raise ImportError("limit must be between 1 and 100")

    batch, staged_rows, site_rows, items = _latest_context(client)
    summary, private_actions = build_wbs_import_plan_details(
        staged_rows,
        site_rows,
    )
    safe_actions = [
        action
        for action in private_actions
        if action["decision"] in SAFE_WBS_DECISIONS
    ]
    selected = safe_actions[offset : offset + limit]
    bindings, missing, conflicts = _selected_item_bindings(selected, items)
    repair_now = datetime.now(timezone.utc).isoformat()
    repair_staged_rows = _repair_staging_rows(
        client,
        str(batch.get("id") or ""),
        _missing_page_ids(selected, items),
    ) if missing > 0 else []
    repair_rows, repair_conflicts = _inventory_repair_rows(
        batch,
        selected,
        items,
        repair_staged_rows,
        now=repair_now,
    )
    report = _report_base(
        summary,
        selected,
        bindings,
        missing,
        conflicts,
        len(repair_rows),
        repair_conflicts,
        mode=mode,
        offset=offset,
        limit=limit,
    )
    if mode == "plan":
        return report

    if not SHA256_PATTERN.fullmatch(expected_plan_sha256):
        raise ImportError("write mode requires a lowercase SHA-256 plan digest")
    if expected_plan_sha256 != summary["plan_sha256"]:
        raise ImportError("expected plan digest does not match the current plan")
    if mode == "repair_inventory":
        if not report["inventory_repair_gate_open"]:
            raise ImportError("selected batch failed the inventory repair gate")
        client.insert_ignore_duplicates(
            "notion_migration_items",
            repair_rows,
            on_conflict="batch_id,source_id",
        )
        _batch, _staged, _site, refreshed_items = _latest_context(client)
        _bindings, missing_after, conflicts_after = _selected_item_bindings(
            selected,
            refreshed_items,
        )
        if missing_after != 0 or conflicts_after != 0:
            raise ImportError("inventory repair verification failed")
        report["mutations"]["items_inventoried_now"] = missing
        report["missing_source_items_after_repair"] = missing_after
        report["mapping_conflicts_after_repair"] = conflicts_after
        report["post_repair_safe_apply_gate_open"] = True
        report["applied_at"] = repair_now
        return report

    if not report["safe_apply_gate_open"]:
        raise ImportError("selected safe batch failed the mapping gate")

    wbs_insert_rows, wbs_update_rows = _wbs_mutation_batches(
        selected,
        site_rows,
    )
    client.upsert("wbs_tasks", wbs_insert_rows, on_conflict="id")
    for row in wbs_update_rows:
        destination_id = str(row["id"])
        client.patch(
            "wbs_tasks",
            [("id", f"eq.{destination_id}")],
            {key: value for key, value in row.items() if key != "id"},
        )
    refreshed_site_rows = client.all_rows(
        "wbs_tasks",
        [
            (
                "select",
                "id,title,instance,status,progress,end_date,updated_at,category",
            ),
            ("order", "id.asc"),
        ],
    )
    destination_results = _verify_destinations(selected, refreshed_site_rows)
    now = datetime.now(timezone.utc).isoformat()

    _upsert_item_phase(
        client,
        bindings,
        frozenset({"skipped"}),
        "queued",
        now=now,
    )
    _upsert_item_phase(
        client,
        bindings,
        frozenset({"inventoried", "queued", "failed"}),
        "exporting",
        now=now,
    )
    imported_now = _upsert_item_phase(
        client,
        bindings,
        frozenset({"exporting"}),
        "imported",
        now=now,
        destination_results=destination_results,
    )
    checks_upserted = _upsert_checks(
        client,
        bindings,
        destination_results,
        now=now,
    )
    report["mutations"] = {
        "wbs_rows": len(wbs_insert_rows) + len(wbs_update_rows),
        "items_inventoried_now": 0,
        "items_imported_now": imported_now,
        "items_already_imported_or_later": sum(
            1
            for _action, item in bindings
            if str(item.get("status") or "") in IMPORTED_OR_LATER
        )
        - imported_now,
        "checks_upserted": checks_upserted,
    }
    report["applied_at"] = now
    return report


def _write_summary(path: Path, report: dict[str, Any]) -> None:
    mutations = report["mutations"]
    lines = [
        "## Notion WBS cloud import",
        "",
        f"- Mode: `{report['mode']}`",
        f"- Plan SHA-256: `{report['plan_sha256']}`",
        f"- Safe logical groups: {report['safe_logical_groups']}",
        f"- Blocked logical groups: {report['blocked_logical_groups']}",
        f"- Selected logical groups: {report['selected_logical_groups']}",
        f"- Selected source items: {report['selected_source_items']}",
        f"- Missing source items: {report['missing_source_items']}",
        f"- Mapping conflicts: {report['mapping_conflicts']}",
        "- Repairable missing source items: "
        f"{report['repairable_missing_source_items']}",
        f"- Inventory repair gate open: {report['inventory_repair_gate_open']}",
        f"- WBS rows written: {mutations['wbs_rows']}",
        f"- Items inventoried now: {mutations['items_inventoried_now']}",
        f"- Items imported now: {mutations['items_imported_now']}",
        f"- Checks written: {mutations['checks_upserted']}",
        "- Notion source deletion attempted: no",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("plan", "repair_inventory", "apply"),
        default=os.environ.get("IMPORT_MODE", "plan"),
    )
    parser.add_argument(
        "--expected-plan-sha256",
        default=os.environ.get("EXPECTED_PLAN_SHA256", ""),
    )
    parser.add_argument(
        "--safe-offset",
        type=int,
        default=int(os.environ.get("SAFE_OFFSET", "0")),
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=int(os.environ.get("IMPORT_LIMIT", "100")),
    )
    parser.add_argument("--json-output", type=Path, required=True)
    parser.add_argument("--summary-output", type=Path)
    return parser


def main() -> int:
    args = _parser().parse_args()
    client = SupabaseImportClient(
        os.environ.get("SUPABASE_URL", ""),
        os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""),
    )
    try:
        report = run_import(
            client,
            mode=args.mode,
            expected_plan_sha256=args.expected_plan_sha256,
            offset=args.safe_offset,
            limit=args.limit,
        )
    except ImportError as exc:
        print(f"notion_wbs_cloud_import_failed:{exc}", file=sys.stderr)
        return 1

    args.json_output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if args.summary_output is not None:
        _write_summary(args.summary_output, report)
    print(json.dumps(report, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
