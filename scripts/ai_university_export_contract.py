#!/usr/bin/env python3
"""Validate the AI University course-review export contract (v1)."""

from __future__ import annotations

import argparse
from datetime import datetime
import json
from pathlib import Path
from typing import Any


BASE_FIELDS = ("id", "provider", "title", "source_url", "is_active")
EVIDENCE_FIELDS = (
    "target_audience",
    "observable_learning_outcome",
    "assessment_verification_method",
    "evidence_source_url",
    "evidence_verified_at",
)
REQUIRED_FIELDS = BASE_FIELDS + EVIDENCE_FIELDS
TEXT_LIMITS = {
    "target_audience": 500,
    "observable_learning_outcome": 1000,
    "assessment_verification_method": 1000,
}


def _timestamp_is_valid(value: object) -> bool:
    if not isinstance(value, str) or not value.strip():
        return False
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None


def _https_url_is_valid(value: object) -> bool:
    return (
        isinstance(value, str)
        and value.startswith("https://")
        and len(value) <= 2048
    )


def validate_export(payload: object) -> dict[str, Any]:
    errors: list[dict[str, Any]] = []
    input_shape = "array"
    if isinstance(payload, dict) and isinstance(payload.get("courses"), list):
        rows = payload["courses"]
        input_shape = "catalog_envelope"
    elif isinstance(payload, list):
        rows = payload
    else:
        return {
            "schema_version": 1,
            "contract": "ai_university_course_review_export_v1",
            "input_shape": "invalid",
            "valid": False,
            "row_count": 0,
            "evidenced_row_count": 0,
            "legacy_null_evidence_row_count": 0,
            "errors": [{"code": "payload_not_array_or_catalog_envelope"}],
        }

    evidenced = 0
    legacy = 0
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            errors.append({"row": index, "code": "row_not_object"})
            continue
        record_id = row.get("id")
        missing_keys = [field for field in REQUIRED_FIELDS if field not in row]
        if missing_keys:
            errors.append(
                {
                    "row": index,
                    "id": record_id,
                    "code": "required_fields_missing",
                    "fields": missing_keys,
                }
            )
            continue

        for field in ("id", "provider", "title", "source_url"):
            if not isinstance(row[field], str) or not row[field].strip():
                errors.append(
                    {
                        "row": index,
                        "id": record_id,
                        "code": "invalid_base_field",
                        "field": field,
                    }
                )
        if not isinstance(row["is_active"], bool):
            errors.append(
                {
                    "row": index,
                    "id": record_id,
                    "code": "invalid_base_field",
                    "field": "is_active",
                }
            )

        values = [row[field] for field in EVIDENCE_FIELDS]
        null_count = sum(value is None for value in values)
        if null_count == len(EVIDENCE_FIELDS):
            legacy += 1
            continue
        if null_count:
            errors.append(
                {
                    "row": index,
                    "id": record_id,
                    "code": "partial_evidence",
                    "fields": [field for field in EVIDENCE_FIELDS if row[field] is None],
                }
            )
            continue

        evidenced += 1
        for field, limit in TEXT_LIMITS.items():
            value = row[field]
            if not isinstance(value, str) or not value.strip() or len(value.strip()) > limit:
                errors.append(
                    {
                        "row": index,
                        "id": record_id,
                        "code": "invalid_evidence_field",
                        "field": field,
                    }
                )
        if not _https_url_is_valid(row["evidence_source_url"]):
            errors.append(
                {
                    "row": index,
                    "id": record_id,
                    "code": "invalid_evidence_field",
                    "field": "evidence_source_url",
                }
            )
        if not _timestamp_is_valid(row["evidence_verified_at"]):
            errors.append(
                {
                    "row": index,
                    "id": record_id,
                    "code": "invalid_evidence_field",
                    "field": "evidence_verified_at",
                }
            )

    return {
        "schema_version": 1,
        "contract": "ai_university_course_review_export_v1",
        "input_shape": input_shape,
        "valid": not errors,
        "row_count": len(rows),
        "evidenced_row_count": evidenced,
        "legacy_null_evidence_row_count": legacy,
        "errors": errors,
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# AI University course-review export contract",
        "",
        f"- Contract: `{report['contract']}`",
        f"- Valid: `{'yes' if report['valid'] else 'no'}`",
        f"- Rows: {report['row_count']}",
        f"- Evidence-complete rows: {report['evidenced_row_count']}",
        f"- Legacy all-NULL evidence rows: {report['legacy_null_evidence_row_count']}",
        f"- Contract errors: {len(report['errors'])}",
    ]
    if report["errors"]:
        lines.extend(["", "## Errors", ""])
        for error in report["errors"]:
            lines.append(f"- `{json.dumps(error, ensure_ascii=False, sort_keys=True)}`")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("export_json", type=Path)
    parser.add_argument("--output-json", type=Path)
    parser.add_argument("--output-md", type=Path)
    args = parser.parse_args(argv)
    report = validate_export(json.loads(args.export_json.read_text(encoding="utf-8")))
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
