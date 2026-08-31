#!/usr/bin/env python3
"""Build deterministic public summaries and private staged Notion WBS actions."""

from __future__ import annotations

import hashlib
import json
import math
import re
from datetime import date, datetime, timezone
from typing import Any


UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-"
    r"[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)
SAFE_WBS_DECISIONS = frozenset(
    {"insert", "update_from_notion", "unchanged", "site_newer_preserved"}
)
BLOCKED_WBS_DECISIONS = frozenset(
    {
        "manual_timestamp_conflict",
        "identity_collision",
        "invalid_fields",
        "conflicting_duplicate",
        "title_group_content_conflict",
    }
)
ALLOWED_WBS_INSTANCES = frozenset(
    {
        "claude", "codex", "codex1", "codex2", "cx",
        "automation", "auto", "user", "usr", "human",
        "gemini", "co-pilot", "copilot", "vscode", "win", "windows",
        "ps", "ps1", "ps2", "ps3", "ps4", "ps5", "ps6",
        "web", "mobile", "schedule", "scheduled", "gha",
        "github-actions", "github-copilot", "all",
    }
)
ALLOWED_WBS_STATUSES = frozenset({"pending", "in_progress", "completed", "blocked"})


def normalized_wbs_uuid(value: object) -> str | None:
    text = str(value or "").strip().lower()
    return text if UUID_PATTERN.fullmatch(text) else None


def _normalize_instance(value: object) -> str:
    instance = str(value or "win").strip().lower()
    aliases = {
        "all": "codex",
        "claude-code": "claude",
        "copilot": "co-pilot",
        "github-copilot": "co-pilot",
    }
    return aliases.get(instance, instance or "win")


def _normalize_status(value: object) -> str:
    status = str(value or "pending").strip().lower()
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


def staged_wbs_content(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "title": str(row.get("title") or ""),
        "instance": _normalize_instance(row.get("instance")),
        "status": _normalize_status(row.get("status")),
        "progress": _normalized_progress(row.get("progress")),
        "deadline": _normalize_deadline(row.get("deadline")),
    }


def site_wbs_content(row: dict[str, Any]) -> dict[str, Any]:
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


def wbs_content_sha256(content: dict[str, Any]) -> str:
    return hashlib.sha256(_content_key(content).encode("utf-8")).hexdigest()


def _canonical_row(rows: list[dict[str, Any]]) -> dict[str, Any]:
    return sorted(
        rows,
        key=lambda row: (
            -_epoch(row.get("source_updated_at")),
            -_epoch(row.get("source_last_edited_at")),
            str(row.get("source_page_id") or ""),
        ),
    )[0]


def wbs_content_validation_errors(content: dict[str, Any]) -> tuple[str, ...]:
    errors: list[str] = []
    if not content["title"].strip() or len(content["title"]) > 10000:
        errors.append("title")
    if content["progress"] is None:
        errors.append("progress")
    if content["instance"] not in ALLOWED_WBS_INSTANCES:
        errors.append("instance")
    if content["status"] not in ALLOWED_WBS_STATUSES:
        errors.append("status")
    deadline = content["deadline"]
    if deadline is not None:
        try:
            date.fromisoformat(deadline)
        except ValueError:
            errors.append("deadline")
    return tuple(errors)


def _invalid_content(content: dict[str, Any]) -> bool:
    return bool(wbs_content_validation_errors(content))


def _compare_to_destination(
    source: dict[str, Any],
    source_row: dict[str, Any],
    destination: dict[str, Any] | None,
) -> str:
    if destination is None:
        return "insert"
    if source == site_wbs_content(destination):
        return "unchanged"
    source_time = _timestamp(source_row.get("source_updated_at"))
    destination_time = _timestamp(destination.get("updated_at"))
    if (
        source_time is not None
        and destination_time is not None
        and source_time > destination_time
    ):
        return "update_from_notion"
    if (
        source_time is not None
        and destination_time is not None
        and source_time < destination_time
    ):
        return "site_newer_preserved"
    return "manual_timestamp_conflict"


def build_wbs_import_plan_details(
    staged_rows: list[dict[str, Any]],
    site_rows: list[dict[str, Any]],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Return a content-free summary and private actions.

    Callers must never log, artifact, or otherwise disclose the private actions.
    """

    staged_groups: dict[str, list[dict[str, Any]]] = {}
    invalid_task_id_rows = 0
    for row in staged_rows:
        task_id = normalized_wbs_uuid(row.get("task_id"))
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
        variants = {_content_key(staged_wbs_content(row)) for row in rows}
        if len(variants) == 1:
            exact_duplicate_groups += 1
        else:
            conflicting_duplicate_groups += 1
            conflicting_duplicate_ids.add(task_id)

    site_by_id: dict[str, dict[str, Any]] = {}
    site_invalid_id_rows = 0
    site_title_owners: dict[tuple[str, str], set[str]] = {}
    for row in site_rows:
        task_id = normalized_wbs_uuid(row.get("id"))
        if task_id is None:
            site_invalid_id_rows += 1
            continue
        site_by_id[task_id] = row
        content = site_wbs_content(row)
        key = (content["title"], content["instance"])
        site_title_owners.setdefault(key, set()).add(task_id)
    site_title_duplicate_groups = sum(
        1 for owners in site_title_owners.values() if len(owners) > 1
    )

    logical_groups: dict[
        tuple[str, str],
        list[tuple[str, dict[str, Any]]],
    ] = {}
    for task_id, row in canonical.items():
        content = staged_wbs_content(row)
        key = (content["title"], content["instance"])
        logical_groups.setdefault(key, []).append((task_id, row))

    decision_counts = {
        "insert": 0,
        "update_from_notion": 0,
        "unchanged": 0,
        "site_newer_preserved": 0,
        "manual_timestamp_conflict": 0,
        "identity_collision": 0,
        "invalid_fields": 0,
        "conflicting_duplicate": 0,
        "title_group_content_conflict": 0,
    }
    validation_errors = {
        "title": 0,
        "progress": 0,
        "instance": 0,
        "status": 0,
        "deadline": 0,
    }
    for row in canonical.values():
        for error in wbs_content_validation_errors(staged_wbs_content(row)):
            validation_errors[error] += 1

    private_actions: list[dict[str, Any]] = []
    blocked_logical_groups = 0
    identity_alias_rows = 0
    destination_ids: set[str] = set()

    for key in sorted(logical_groups):
        candidates = sorted(logical_groups[key], key=lambda item: item[0])
        task_ids = [task_id for task_id, _ in candidates]
        rows = [row for _, row in candidates]
        contents = [staged_wbs_content(row) for row in rows]
        source_row = _canonical_row(rows)
        source_content = staged_wbs_content(source_row)
        existing_candidate_ids = [
            task_id for task_id in task_ids if task_id in site_by_id
        ]
        title_owners = site_title_owners.get(key, set())
        destination_id: str | None = None

        if any(_invalid_content(content) for content in contents):
            decision = "invalid_fields"
        elif any(task_id in conflicting_duplicate_ids for task_id in task_ids):
            decision = "conflicting_duplicate"
        elif len(existing_candidate_ids) > 1:
            decision = "identity_collision"
        elif len(title_owners) > 1:
            decision = "identity_collision"
        elif existing_candidate_ids:
            destination_id = existing_candidate_ids[0]
            if title_owners and destination_id not in title_owners:
                decision = "identity_collision"
            elif len({_content_key(content) for content in contents}) > 1:
                decision = "title_group_content_conflict"
            else:
                decision = _compare_to_destination(
                    source_content,
                    source_row,
                    site_by_id[destination_id],
                )
        elif title_owners:
            destination_id = next(iter(title_owners))
            if len({_content_key(content) for content in contents}) > 1:
                decision = "title_group_content_conflict"
            else:
                decision = _compare_to_destination(
                    source_content,
                    source_row,
                    site_by_id[destination_id],
                )
        elif len({_content_key(content) for content in contents}) > 1:
            decision = "title_group_content_conflict"
        else:
            destination_id = min(task_ids)
            decision = _compare_to_destination(
                source_content,
                source_row,
                site_by_id.get(destination_id),
            )

        decision_counts[decision] += 1
        if decision in BLOCKED_WBS_DECISIONS:
            blocked_logical_groups += 1
        if destination_id is not None:
            destination_ids.add(destination_id)
            identity_alias_rows += sum(
                1 for task_id in task_ids if task_id != destination_id
            )

        source_page_ids = sorted(
            str(row.get("source_page_id") or "")
            for task_id in task_ids
            for row in staged_groups[task_id]
        )
        private_actions.append(
            {
                "source_task_ids": task_ids,
                "source_page_ids": source_page_ids,
                "destination_task_id": destination_id,
                "source_updated_at": source_row.get("source_updated_at"),
                "source_last_edited_at": source_row.get("source_last_edited_at"),
                "content": source_content,
                "decision": decision,
            }
        )

    canonical_ids = set(canonical)
    site_only_rows = len(set(site_by_id) - canonical_ids)
    site_unmatched_rows = len(set(site_by_id) - destination_ids)
    blockers = (
        invalid_task_id_rows
        + site_invalid_id_rows
        + site_title_duplicate_groups
        + blocked_logical_groups
    )
    plan_sha256 = hashlib.sha256(
        json.dumps(
            private_actions,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()

    summary = {
        "staged_rows": len(staged_rows),
        "canonical_rows": len(canonical),
        "logical_rows": len(logical_groups),
        "identity_alias_rows": identity_alias_rows,
        "site_rows": len(site_rows),
        "site_only_rows": site_only_rows,
        "site_unmatched_rows": site_unmatched_rows,
        "duplicate_rows": duplicate_rows,
        "exact_duplicate_groups": exact_duplicate_groups,
        "conflicting_duplicate_groups": conflicting_duplicate_groups,
        "invalid_task_id_rows": invalid_task_id_rows,
        "site_invalid_id_rows": site_invalid_id_rows,
        "site_title_duplicate_groups": site_title_duplicate_groups,
        "identity_collisions": decision_counts["identity_collision"],
        "title_group_content_conflicts": decision_counts[
            "title_group_content_conflict"
        ],
        "invalid_field_rows": decision_counts["invalid_fields"],
        "validation_errors": validation_errors,
        "decisions": decision_counts,
        "blocked_logical_groups": blocked_logical_groups,
        "blockers": blockers,
        "apply_gate_open": blockers == 0 and len(logical_groups) > 0,
        "safe_logical_groups": sum(
            decision_counts[decision] for decision in SAFE_WBS_DECISIONS
        ),
        "plan_sha256": plan_sha256,
    }
    return summary, private_actions


def build_wbs_import_plan(
    staged_rows: list[dict[str, Any]],
    site_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    """Return aggregate decisions and a digest, never source content or IDs."""

    summary, _private_actions = build_wbs_import_plan_details(
        staged_rows,
        site_rows,
    )
    return summary
