#!/usr/bin/env python3
"""Aggregate batched WBS GitHub Issue sync responses."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SUM_FIELDS = (
    "issue_count",
    "created",
    "updated",
    "completed_from_closed_issues",
    "duplicate_wbs_closed",
    "stale_wbs_repaired",
    "wbs_task_scan_count",
    "skipped",
)

LIST_FIELDS = (
    "issues_to_close",
    "duplicate_wbs_tasks",
    "repaired_wbs_tasks",
)


def as_int(value: Any) -> int:
    if value is None or value == "":
        return 0
    return int(value)


def item_key(item: Any) -> str:
    return json.dumps(item, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def extend_unique(target: list[Any], seen: set[str], items: Any) -> None:
    if not isinstance(items, list):
        return
    for item in items:
        key = item_key(item)
        if key in seen:
            continue
        target.append(item)
        seen.add(key)


def iter_response_lines(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []

    responses: list[dict[str, Any]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        responses.append(json.loads(line))
    return responses


def read_failures(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []

    failures: list[dict[str, Any]] = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line:
            continue
        batch_number, http_code = line.split("\t", 1)
        failures.append({"batch": int(batch_number), "http_code": http_code})
    return failures


def aggregate_responses(
    responses: list[dict[str, Any]],
    failures: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    aggregate: dict[str, Any] = {
        "success": True,
        "issues_to_close": [],
        "duplicate_wbs_tasks": [],
        "repaired_wbs_tasks": [],
        "batch_failures": [],
    }
    for field in SUM_FIELDS:
        aggregate[field] = 0

    seen_items = {field: set() for field in LIST_FIELDS}
    for response in responses:
        aggregate["success"] = aggregate["success"] and bool(response.get("success", False))
        for field in SUM_FIELDS:
            aggregate[field] += as_int(response.get(field))
        for field in LIST_FIELDS:
            extend_unique(aggregate[field], seen_items[field], response.get(field))

    if failures:
        aggregate["success"] = False
        aggregate["batch_failures"].extend(failures)

    return aggregate


def aggregate_from_files(responses_path: Path, failures_path: Path) -> dict[str, Any]:
    return aggregate_responses(
        iter_response_lines(responses_path),
        read_failures(failures_path),
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--responses", type=Path, required=True)
    parser.add_argument("--failures", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)

    aggregate = aggregate_from_files(args.responses, args.failures)
    output = json.dumps(aggregate, ensure_ascii=False)
    if args.output:
        args.output.write_text(output + "\n", encoding="utf-8")
    else:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
