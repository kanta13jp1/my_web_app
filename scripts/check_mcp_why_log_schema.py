#!/usr/bin/env python3
"""Deterministic CI validator for MCP Why reasoning_context logs (#2814)."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
from datetime import datetime
import json
from pathlib import Path
import sys
from typing import Any

REQUIRED_SCHEMA_KEYS: tuple[str, ...] = (
    "availableTools",
    "selectedTool",
    "reasoningWhy",
    "serverName",
    "timestamp",
)


@dataclass(frozen=True)
class ValidationReport:
    valid: bool
    errors: list[str]


def validate_schema_file(schema_path: Path) -> ValidationReport:
    """Validate that the JSON Schema file declares all required properties."""
    if not schema_path.is_file():
        return ValidationReport(
            valid=False,
            errors=[f"Missing schema file: {schema_path}"],
        )

    data = json.loads(schema_path.read_text(encoding="utf-8"))
    errors: list[str] = []
    required = set(data.get("required", []))
    props = data.get("properties", {})

    for key in REQUIRED_SCHEMA_KEYS:
        if key not in required:
            errors.append(f"Schema missing required field: {key}")
        if key not in props:
            errors.append(f"Schema missing property definition: {key}")

    if "promptHash" not in props or "promptSummary" not in props:
        errors.append(
            "Schema must define both promptHash and promptSummary properties.",
        )

    return ValidationReport(valid=len(errors) == 0, errors=errors)


def validate_reasoning_context(payload: Any) -> ValidationReport:
    """Validate a single reasoning_context log payload."""
    if not isinstance(payload, dict):
        return ValidationReport(
            valid=False,
            errors=["reasoning_context must be a JSON object."],
        )

    errors: list[str] = []
    tools = payload.get("availableTools")
    if (
        not isinstance(tools, list)
        or len(tools) == 0
        or not all(isinstance(t, str) and t.strip() for t in tools)
    ):
        errors.append("availableTools must be a non-empty list of strings.")

    for field in ("selectedTool", "reasoningWhy", "serverName", "timestamp"):
        val = payload.get(field)
        if not isinstance(val, str) or not val.strip():
            errors.append(f"{field} must be a non-empty string.")

    p_hash = payload.get("promptHash")
    p_sum = payload.get("promptSummary")
    has_hash = isinstance(p_hash, str) and bool(p_hash.strip())
    has_sum = isinstance(p_sum, str) and bool(p_sum.strip())
    if not (has_hash or has_sum):
        errors.append("Either promptHash or promptSummary must be non-empty.")

    if not errors:
        clean_tools = [t.strip() for t in tools]
        selected = str(payload["selectedTool"]).strip()
        if selected not in clean_tools:
            errors.append(
                f"selectedTool '{selected}' is not in availableTools.",
            )
        ts_raw = str(payload["timestamp"]).strip()
        try:
            datetime.fromisoformat(ts_raw.replace("Z", "+00:00"))
        except ValueError:
            errors.append("timestamp must be a valid ISO-8601 date-time.")

    return ValidationReport(valid=len(errors) == 0, errors=errors)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate MCP Why reasoning_context schema and payloads.",
    )
    parser.add_argument(
        "--schema",
        default="docs/schemas/mcp_reasoning_context.schema.json",
        help="Path to mcp_reasoning_context.schema.json.",
    )
    parser.add_argument(
        "--sample",
        help="Optional JSON file containing a sample reasoning_context log.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Print structured JSON validation output.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    schema_res = validate_schema_file(Path(args.schema))
    sample_res: ValidationReport | None = None
    if args.sample:
        sample_payload = json.loads(
            Path(args.sample).read_text(encoding="utf-8"),
        )
        sample_res = validate_reasoning_context(sample_payload)

    overall_valid = schema_res.valid and (
        sample_res.valid if sample_res is not None else True
    )
    if args.json:
        print(
            json.dumps(
                {
                    "valid": overall_valid,
                    "schema": asdict(schema_res),
                    "sample": asdict(sample_res) if sample_res else None,
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    return 0 if overall_valid else 1


if __name__ == "__main__":
    raise SystemExit(main())
