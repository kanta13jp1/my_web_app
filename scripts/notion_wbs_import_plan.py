#!/usr/bin/env python3
"""Build a deterministic, content-free plan for staged Notion WBS import."""

from __future__ import annotations

import hashlib
import json
import math
import re
from datetime import datetime, timezone
from typing import Any


UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-"
    r"[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)


def _normalized_uuid(value: object) -> str | None:
    text = str(value or "").strip().lower()
    return text if UUID_PATTERN.fullmatch(text) else None


def _normalize_instance(value: object) -> str:
    instance = str(value or "win").strip()
    if instance == "all":
        return "codex"
    if instance in {"copilot", "github-copilot"}:
        return "co-pilot"
    return instance or "win"


def _normalize_status(value: object) -> str:
    status = str(value or "pending").strip()
    if status == "in-progress":
        return "in_progress"
    if status in {"not_started", "draft"}:
        return "pending"
    if status == "done":
        return "completed"
    return status or "pending"


def _normalize_deadline(value: object) -> str | None:
    text = str(value or "").strip()
    return text[:10] if text else None


def _normalized_progress(value: object) -> int | None:
    try:
        progress = float(value if value is not None else 0)
    except (TypeError, ValueError):
        return None
    if not math.isfinite(progress) or not progress.is_integer():
        return None
    result = int(progress)
    return result if 0 <= result <= 100 else None


def _timestamp(value: object) -> datetime | None:
    text = str(value or "").strip()
    if not text:
        return None
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def _epoch(value: object) -> float:
    parsed = _timestamp(value)
    return parsed.timestamp() if parsed is not None else float("-inf")


def _staged_content(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "title": str(row.get("title") or ""),
        "instance": _normalize_instance(row.get("instance")),
        "status": _normalize_status(row.get("status")),
        "progress": _normalized_progress(row.get("progress")),
        "deadline": _normalize_deadline(row.get("deadline")),
    }


def _site_content(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "title": str(row.get("title") or ""),
        "instance": _normalize_instance(row.get("instance")),
        "status": _normalize_status(row.get("status")),
        "progress": _normalized_progress(row.get("progress")),
        "deadline": _normalize_deadline(row.get("end_date")),
    }


def _content_key(content: dict[str, Any]) -> str:
    return json.dumps(
        content,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )


def _canonical_row(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return sorted(
        rows,
        key=lambda row: (
            -_epoch(row.get("source_updated_at")),
            -_epoch(row.get("source_last_edited_at")),
            str(row.get("source_page_id") or ""),
        ),
    )[0]


def build_wbs_import_plan(
    staged_rows: list[dict[str, Any]],
    site_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    """Return aggregate decisions and a digest, never source content or IDs."""

    staged_groups: dict[str, list[dict[str, Any]]] = {}
    invalid_task_id_rows = 0
    for row in staged_rows:
        task_id = _normalized_uuid(row.get("task_id"))
        if task_id is None:
            invalid_task_id_rows += 1
            continue
        staged_groups.setdefault(task_id, []).append(row)

    canonical: dict[str, dict[str, Any]] = {}
    exact_duplicate_groups = 0
    conflicting_duplicate_groups = 0
    duplicate_rows = 0
    conflicting_duplicate_ids: set[str] = set()
    for task_id, rows in staged_groups.items():
        canonical[task_id] = _canonical_row(rows)
        if len(rows) <= 1:
            continue
        duplicate_rows += len(rows) - 1
        variants = {_content_key(_staged_content(row)) for row in rows}
        if len(variants) == 1:
            exact_duplicate_groups += 1
        else:
            conflicting_duplicate_groups += 1
            conflicting_duplicate_ids.add(task_id)

    site_by_id: dict[str, dict[str, Any]] = {}
    site_invalid_id_rows = 0
    site_title_owners: dict[tuple[str, str], str] = {}
    for row in site_rows:
        task_id = _normalized_uuid(row.get("id"))
        if task_id is None:
            site_invalid_id_rows += 1
            continue
        site_by_id[task_id] = row
        content = _site_content(row)
        site_title_owners[(content["title"], content["instance"])] = task_id

    desired_key_owners: dict[tuple[str, str], set[str]] = {}
    for task_id, row in canonical.items():
        content = _staged_content(row)
        key = (content["title"], content["instance"])
        desired_key_owners.setdefault(key, set()).add(task_id)

    title_conflict_ids: set[str] = set()
    for key, desired_ids in desired_key_owners.items():
        site_owner = site_title_owners.get(key)
        for task_id in desired_ids:
            if site_owner is not None and site_owner != task_id:
                title_conflict_ids.add(task_id)
        if len(desired_ids) > 1:
            title_conflict_ids.update(desired_ids)

    decision_counts = {
        "insert": 0,
        "update_from_notion": 0,
        "unchanged": 0,
        "site_newer_preserved": 0,
        "manual_timestamp_conflict": 0,
        "title_instance_conflict": 0,
        "invalid_fields": 0,
        "conflicting_duplicate": 0,
    }
    digest_rows: list[dict[str, Any]] = []
    invalid_field_ids: set[str] = set()
    for task_id in sorted(canonical):
        row = canonical[task_id]
        content = _staged_content(row)
        if (
            not content["title"].strip()
            or content["progress"] is None
            or len(content["title"]) > 10000
        ):
            decision = "invalid_fields"
            invalid_field_ids.add(task_id)
        elif task_id in conflicting_duplicate_ids:
            decision = "conflicting_duplicate"
        elif task_id in title_conflict_ids:
            decision = "title_instance_conflict"
        else:
            site = site_by_id.get(task_id)
            if site is None:
                decision = "insert"
            elif content == _site_content(site):
                decision = "unchanged"
            else:
                source_time = _timestamp(row.get("source_updated_at"))
                site_time = _timestamp(site.get("updated_at"))
                if (
                    source_time is not None
                    and site_time is not None
                    and source_time > site_time
                ):
                    decision = "update_from_notion"
                elif (
                    source_time is not None
                    and site_time is not None
                    and source_time < site_time
                ):
                    decision = "site_newer_preserved"
                else:
                    decision = "manual_timestamp_conflict"

        decision_counts[decision] += 1
        digest_rows.append(
            {
                "task_id": task_id,
                "source_page_id": str(row.get("source_page_id") or ""),
                "source_updated_at": row.get("source_updated_at"),
                "source_last_edited_at": row.get("source_last_edited_at"),
                "content": content,
                "decision": decision,
            }
        )

    canonical_ids = set(canonical)
    site_only_rows = len(set(site_by_id) - canonical_ids)
    blockers = (
        invalid_task_id_rows
        + site_invalid_id_rows
        + conflicting_duplicate_groups
        + len(title_conflict_ids)
        + len(invalid_field_ids)
        + decision_counts["manual_timestamp_conflict"]
    )
    plan_sha256 = hashlib.sha256(
        json.dumps(
            digest_rows,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()

    return {
        "staged_rows": len(staged_rows),
        "canonical_rows": len(canonical),
        "site_rows": len(site_rows),
        "site_only_rows": site_only_rows,
        "duplicate_rows": duplicate_rows,
        "exact_duplicate_groups": exact_duplicate_groups,
        "conflicting_duplicate_groups": conflicting_duplicate_groups,
        "invalid_task_id_rows": invalid_task_id_rows,
        "site_invalid_id_rows": site_invalid_id_rows,
        "title_instance_conflicts": len(title_conflict_ids),
        "invalid_field_rows": len(invalid_field_ids),
        "decisions": decision_counts,
        "blockers": blockers,
        "apply_gate_open": blockers == 0 and len(canonical) > 0,
        "plan_sha256": plan_sha256,
    }