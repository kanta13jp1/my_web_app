#!/usr/bin/env python3
"""Fail-closed rollout policy for the Issue #2844 deletion worker."""

from __future__ import annotations

import argparse
import json
import os
from dataclasses import asdict, dataclass
from pathlib import Path


STAGES = {"disabled", "canary", "limited", "full"}


@dataclass(frozen=True)
class RolloutDecision:
    mode: str
    stage: str
    max_requests: int
    request_id: int | None
    reason: str
    expected_confirmation: str


def parse_bool(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def positive_integer(value: object, field: str) -> int:
    text = str(value).strip()
    if not text.isdigit() or int(text) <= 0:
        raise ValueError(f"{field} must be a positive integer")
    return int(text)


def decide(
    *,
    event_name: str,
    stage: str,
    automation_enabled: bool,
    apply_requested: bool,
    request_id_raw: object,
    max_requests_raw: object,
    confirmation: str,
) -> RolloutDecision:
    stage = stage.strip().lower() or "disabled"
    if stage not in STAGES:
        raise ValueError("rollout stage must be disabled, canary, limited, or full")

    request_text = str(request_id_raw or "").strip()
    request_id = (
        positive_integer(request_text, "request_id") if request_text else None
    )

    if event_name == "schedule":
        if not automation_enabled:
            return RolloutDecision(
                "skip", stage, 0, None, "automation_kill_switch_disabled", ""
            )
        if stage not in {"limited", "full"}:
            return RolloutDecision(
                "skip", stage, 0, None, "stage_disallows_scheduled_deletion", ""
            )
        batch_size = 1 if stage == "limited" else 10
        return RolloutDecision(
            "apply", stage, batch_size, None, "scheduled_stage_authorized", ""
        )

    if event_name != "workflow_dispatch":
        raise ValueError("unsupported event_name")

    max_requests = positive_integer(max_requests_raw, "max_requests")
    if max_requests > 50:
        raise ValueError("max_requests must not exceed 50")
    if not apply_requested:
        return RolloutDecision(
            "preflight", stage, 0, request_id, "manual_preflight", ""
        )
    if stage == "disabled":
        raise ValueError("destructive processing is disabled by rollout stage")

    if stage == "canary":
        if request_id is None:
            raise ValueError("canary apply requires an exact request_id")
        if max_requests != 1:
            raise ValueError("canary apply requires max_requests=1")
        expected = f"DELETE REQUEST {request_id}"
    else:
        stage_limit = 5 if stage == "limited" else 50
        if max_requests > stage_limit:
            raise ValueError(
                f"{stage} apply allows at most {stage_limit} request(s)"
            )
        expected = f"DELETE UP TO {max_requests}"

    if confirmation.strip() != expected:
        raise ValueError(f"confirmation must exactly match: {expected}")
    return RolloutDecision(
        "apply", stage, max_requests, request_id, "manual_apply_authorized", expected
    )


def write_github_output(path: Path, decision: RolloutDecision) -> None:
    values = asdict(decision)
    with path.open("a", encoding="utf-8") as output:
        for key, value in values.items():
            if value is None:
                value = ""
            output.write(f"{key}={value}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    try:
        decision = decide(
            event_name=os.environ.get("EVENT_NAME", ""),
            stage=os.environ.get("ROLLOUT_STAGE", "disabled"),
            automation_enabled=parse_bool(
                os.environ.get("AUTOMATION_ENABLED", "false")
            ),
            apply_requested=parse_bool(os.environ.get("APPLY_REQUESTED", "false")),
            request_id_raw=os.environ.get("REQUEST_ID", ""),
            max_requests_raw=os.environ.get("MAX_REQUESTS", "1"),
            confirmation=os.environ.get("CONFIRMATION", ""),
        )
    except ValueError as error:
        parser.error(str(error))

    print(json.dumps(asdict(decision), ensure_ascii=False, sort_keys=True))
    if args.github_output:
        write_github_output(args.github_output, decision)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
