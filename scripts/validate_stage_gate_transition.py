#!/usr/bin/env python3
"""Deterministic stage-gate validator for Issue / NotebookLM task transitions (#2593)."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Sequence

STAGE_SEQUENCE: tuple[str, ...] = (
    "intake",
    "design",
    "implementation",
    "verification",
    "release",
)

CHECKLIST_RE = re.compile(r"^\s*[-*]\s+\[(?: |x|X)\]\s+\S+", re.MULTILINE)


@dataclass(frozen=True)
class StageGateValidationResult:
    valid: bool
    current_stage: str
    target_stage: str
    errors: tuple[str, ...]
    checklist_items: int

    def to_dict(self) -> dict[str, object]:
        payload = asdict(self)
        payload["errors"] = list(self.errors)
        return payload


def validate_stage_transition(
    *,
    current_stage: str,
    target_stage: str,
    title: str,
    source_ref: str,
    body: str = "",
) -> StageGateValidationResult:
    """Validate a single sequential forward stage transition."""
    current = current_stage.strip().lower()
    target = target_stage.strip().lower()
    errors: list[str] = []

    if current not in STAGE_SEQUENCE:
        errors.append(f"Unknown current stage: {current_stage!r}")
    if target not in STAGE_SEQUENCE:
        errors.append(f"Unknown target stage: {target_stage!r}")
    if not title.strip():
        errors.append("Title is required before stage-gate evaluation.")
    if not source_ref.strip():
        errors.append("Source reference is required before stage-gate evaluation.")

    if current in STAGE_SEQUENCE and target in STAGE_SEQUENCE:
        current_idx = STAGE_SEQUENCE.index(current)
        target_idx = STAGE_SEQUENCE.index(target)
        if target_idx <= current_idx:
            errors.append(
                f"Target stage '{target}' must advance beyond '{current}'."
            )
        elif target_idx != current_idx + 1:
            expected_next = STAGE_SEQUENCE[current_idx + 1]
            errors.append(
                f"Cannot skip stage: next stage after '{current}' is '{expected_next}', got '{target}'."
            )

    checklist_items = len(CHECKLIST_RE.findall(body))
    if target in ("implementation", "verification", "release") and checklist_items == 0:
        errors.append(
            f"Stage '{target}' requires at least one markdown checklist item (- [ ] ...) in body."
        )

    return StageGateValidationResult(
        valid=not errors,
        current_stage=current,
        target_stage=target,
        errors=tuple(errors),
        checklist_items=checklist_items,
    )


def extract_stage_from_labels(labels: Sequence[str]) -> str | None:
    """Resolve the highest stage:<name> label attached to an issue."""
    found_indices: list[int] = []
    for raw in labels:
        normalized = raw.strip().lower()
        if not normalized.startswith("stage:"):
            continue
        stage_name = normalized.split(":", 1)[1].strip()
        if stage_name in STAGE_SEQUENCE:
            found_indices.append(STAGE_SEQUENCE.index(stage_name))
    if not found_indices:
        return None
    return STAGE_SEQUENCE[max(found_indices)]


def _parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--current-stage", default=os.environ.get("STAGE_GATE_CURRENT", ""))
    parser.add_argument("--target-stage", default=os.environ.get("STAGE_GATE_TARGET", ""))
    parser.add_argument("--title", default=os.environ.get("STAGE_GATE_TITLE", ""))
    parser.add_argument("--source-ref", default=os.environ.get("STAGE_GATE_SOURCE_REF", ""))
    parser.add_argument("--body-file", default="")
    parser.add_argument("--event-path", default="")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    current_stage = args.current_stage
    target_stage = args.target_stage
    title = args.title
    source_ref = args.source_ref
    body = ""

    if args.body_file:
        body = Path(args.body_file).read_text(encoding="utf-8")
    elif args.event_path and Path(args.event_path).is_file():
        event = json.loads(Path(args.event_path).read_text(encoding="utf-8"))
        issue = event.get("issue") if isinstance(event, dict) else None
        if isinstance(issue, dict):
            title = title or str(issue.get("title") or "")
            issue_num = issue.get("number")
            if not source_ref and issue_num is not None:
                source_ref = f"#{issue_num}"
            body = str(issue.get("body") or "")
            raw_labels = [
                str(item.get("name") or "")
                for item in (issue.get("labels") or [])
                if isinstance(item, dict)
            ]
            labeled_stage = extract_stage_from_labels(raw_labels)
            if labeled_stage is not None and not target_stage:
                target_stage = labeled_stage
                if target_stage in STAGE_SEQUENCE and STAGE_SEQUENCE.index(target_stage) > 0:
                    current_stage = current_stage or STAGE_SEQUENCE[STAGE_SEQUENCE.index(target_stage) - 1]
                else:
                    current_stage = current_stage or "intake"
                    target_stage = "design"

    if not current_stage and not target_stage:
        current_stage = "intake"
        target_stage = "design"

    result = validate_stage_transition(
        current_stage=current_stage,
        target_stage=target_stage,
        title=title,
        source_ref=source_ref,
        body=body,
    )
    if args.json:
        print(json.dumps(result.to_dict(), ensure_ascii=False, indent=2))
    else:
        status = "PASS" if result.valid else "FAIL"
        print(
            f"Stage-gate validation {status}: {result.current_stage} -> {result.target_stage} "
            f"(checklist_items={result.checklist_items})"
        )
        for err in result.errors:
            print(f" - {err}")
    return 0 if result.valid else 1


if __name__ == "__main__":
    raise SystemExit(main())
