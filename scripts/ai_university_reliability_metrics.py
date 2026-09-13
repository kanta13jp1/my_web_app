#!/usr/bin/env python3
"""Aggregate anonymous AI University reliability events without setting policy."""

from __future__ import annotations

import argparse
from collections import Counter
from datetime import datetime
import json
from pathlib import Path
import re
from typing import Any


EVENT_NAMES = (
    "content_fetch_failed",
    "fallback_shown",
    "retry_requested",
    "retry_succeeded",
    "retry_failed",
)
CONTENT_RANGE = re.compile(r"(?:\d+)-(?:\d+)/(\d+|\*)")


def _parse_timestamp(value: object) -> datetime | None:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return parsed if parsed.tzinfo is not None else None


def _ratio(numerator: int, denominator: int) -> float | None:
    return round(numerator / denominator, 6) if denominator else None


def expected_count_from_headers(path: Path | None) -> int | None:
    if path is None or not path.exists():
        return None
    match = CONTENT_RANGE.search(path.read_text(encoding="utf-8", errors="replace"))
    if not match or match.group(1) == "*":
        return None
    return int(match.group(1))


def build_report(
    payload: object,
    *,
    expected_count: int | None = None,
    window_start_at: datetime | None = None,
    window_end_at: datetime | None = None,
) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    counts: Counter[str] = Counter()
    timestamps: list[datetime] = []
    rows = payload if isinstance(payload, list) else []
    if not isinstance(payload, list):
        errors.append({"code": "payload_not_array"})
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append({"row": index, "code": "row_not_object"})
            continue
        event_name = row.get("event_name")
        occurred_at = _parse_timestamp(row.get("occurred_at"))
        if event_name not in EVENT_NAMES:
            errors.append({"row": index, "code": "unknown_event_name"})
            continue
        if row.get("surface") != "ai_university_content":
            errors.append({"row": index, "code": "unexpected_surface"})
            continue
        if occurred_at is None:
            errors.append({"row": index, "code": "invalid_occurred_at"})
            continue
        if window_start_at is not None and occurred_at < window_start_at:
            errors.append({"row": index, "code": "event_before_window"})
            continue
        if window_end_at is not None and occurred_at >= window_end_at:
            errors.append({"row": index, "code": "event_after_window"})
            continue
        counts[event_name] += 1
        timestamps.append(occurred_at)

    retry_outcomes = counts["retry_succeeded"] + counts["retry_failed"]
    input_count = len(rows)
    truncated = expected_count is not None and expected_count > input_count
    return {
        "schema_version": 1,
        "mode": "read_only_directional_metrics",
        "valid": not errors,
        "input_row_count": input_count,
        "valid_event_count": sum(counts.values()),
        "expected_row_count": expected_count,
        "input_truncated": truncated,
        "requested_window_start_at": (
            window_start_at.isoformat() if window_start_at is not None else None
        ),
        "requested_window_end_at": (
            window_end_at.isoformat() if window_end_at is not None else None
        ),
        "window_first_event_at": min(timestamps).isoformat() if timestamps else None,
        "window_last_event_at": max(timestamps).isoformat() if timestamps else None,
        "counts": {name: counts[name] for name in EVENT_NAMES},
        "ratios": {
            "fallbacks_per_fetch_failure": _ratio(
                counts["fallback_shown"], counts["content_fetch_failed"]
            ),
            "retry_success_rate": _ratio(counts["retry_succeeded"], retry_outcomes),
            "retry_outcomes_per_request": _ratio(retry_outcomes, counts["retry_requested"]),
        },
        "threshold_evaluation": {
            "status": "not_configured",
            "automated_decision_allowed": False,
            "reason": "Issue #4738 requires real usage and product-approved thresholds.",
        },
        "data_quality_warnings": (
            ["input_truncated"] if truncated else []
        ) + (["anonymous_events_are_spammable"] if rows else []),
        "errors": errors,
    }


def render_markdown(report: dict[str, Any]) -> str:
    ratios = report["ratios"]

    def display_ratio(item: float | None) -> str:
        return "n/a" if item is None else f"{item:.2%}"

    lines = [
        "# AI University reliability metrics",
        "",
        "- Mode: read-only, anonymous directional signals",
        f"- Valid events: {report['valid_event_count']}",
        f"- Input truncated: `{'yes' if report['input_truncated'] else 'no'}`",
        f"- Requested window: `{report['requested_window_start_at'] or 'unspecified'}` "
        f"to `{report['requested_window_end_at'] or 'unspecified'}`",
        "- Threshold evaluation: `not_configured` (no automated decision)",
        "",
        "| Metric | Value |",
        "| --- | ---: |",
    ]
    for name, count in report["counts"].items():
        lines.append(f"| `{name}` | {count} |")
    lines.extend(
        [
            "| Fallbacks per fetch failure | "
            f"{display_ratio(ratios['fallbacks_per_fetch_failure'])} |",
            f"| Retry success rate | {display_ratio(ratios['retry_success_rate'])} |",
            "| Retry outcomes per request | "
            f"{display_ratio(ratios['retry_outcomes_per_request'])} |",
            "",
            "Anonymous events can be spammed. Do not derive alert thresholds or "
            "automated actions from this report alone.",
        ]
    )
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("events_json", type=Path)
    parser.add_argument("--headers", type=Path)
    parser.add_argument("--window-start")
    parser.add_argument("--window-end")
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--output-md", type=Path)
    args = parser.parse_args(argv)
    payload = json.loads(args.events_json.read_text(encoding="utf-8"))
    window_start = _parse_timestamp(args.window_start) if args.window_start else None
    window_end = _parse_timestamp(args.window_end) if args.window_end else None
    if args.window_start and window_start is None:
        parser.error("--window-start must be a timezone-aware ISO 8601 timestamp")
    if args.window_end and window_end is None:
        parser.error("--window-end must be a timezone-aware ISO 8601 timestamp")
    if window_start is not None and window_end is not None and window_start >= window_end:
        parser.error("--window-start must precede --window-end")
    report = build_report(
        payload,
        expected_count=expected_count_from_headers(args.headers),
        window_start_at=window_start,
        window_end_at=window_end,
    )
    if args.output_json:
        args.output_json.parent.mkdir(parents=True, exist_ok=True)
        args.output_json.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    markdown = render_markdown(report)
    if args.output_md:
        args.output_md.parent.mkdir(parents=True, exist_ok=True)
        args.output_md.write_text(markdown, encoding="utf-8")
    return 0 if report["valid"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
