#!/usr/bin/env python3
"""Create a fail-closed Claude Code Remote Control server launch plan.

This script never starts Claude Code. It produces an argument vector only when
the organization security review is recorded and the host resource gate passes.
"""

from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from codex_session_check import physical_memory_snapshot


RAM_USED_BLOCK_PCT = 85.0
RAM_FREE_BLOCK_GB = 4.0
DISK_FREE_BLOCK_GB = 30.0
MAX_MULTI_SESSION_CAPACITY = 2


@dataclass(frozen=True)
class HostResources:
    ram_used_pct: float | None
    ram_free_gb: float | None
    disk_free_gb: float | None


@dataclass(frozen=True)
class ServerPlan:
    status: str
    mode: str
    capacity: int | None
    command: list[str]
    blockers: list[str]
    resource_policy: dict[str, float | int]


def current_resources(root: Path) -> HostResources:
    memory = physical_memory_snapshot()
    disk_root = Path(root.anchor) if root.anchor else root
    try:
        disk_free_gb: float | None = round(
            shutil.disk_usage(disk_root).free / (1024**3),
            2,
        )
    except OSError:
        disk_free_gb = None
    return HostResources(
        ram_used_pct=memory["used_pct"],
        ram_free_gb=memory["free_gb"],
        disk_free_gb=disk_free_gb,
    )


def _resource_blockers(resources: HostResources) -> list[str]:
    blockers: list[str] = []
    if resources.ram_used_pct is None or resources.ram_free_gb is None:
        blockers.append("physical memory could not be measured")
    else:
        if resources.ram_used_pct >= RAM_USED_BLOCK_PCT:
            blockers.append(
                f"RAM use {resources.ram_used_pct:.1f}% is at or above "
                f"{RAM_USED_BLOCK_PCT:.1f}%"
            )
        if resources.ram_free_gb < RAM_FREE_BLOCK_GB:
            blockers.append(
                f"free RAM {resources.ram_free_gb:.2f} GB is below "
                f"{RAM_FREE_BLOCK_GB:.2f} GB"
            )
    if resources.disk_free_gb is None:
        blockers.append("free disk could not be measured")
    elif resources.disk_free_gb < DISK_FREE_BLOCK_GB:
        blockers.append(
            f"free disk {resources.disk_free_gb:.2f} GB is below "
            f"{DISK_FREE_BLOCK_GB:.2f} GB"
        )
    return blockers


def build_server_plan(
    *,
    mode: str,
    requested_capacity: int | None,
    security_review_recorded: bool,
    resources: HostResources,
) -> ServerPlan:
    blockers = _resource_blockers(resources)
    capacity: int | None = None

    if not security_review_recorded:
        blockers.append(
            "organization Owner and security/legal review has not been recorded"
        )

    if mode == "same-dir":
        blockers.append(
            "same-dir mode is prohibited because concurrent sessions can edit the same files"
        )
    elif mode == "single":
        if requested_capacity is not None:
            blockers.append("--capacity cannot be combined with --spawn=session")
    elif mode == "multi":
        capacity = (
            MAX_MULTI_SESSION_CAPACITY
            if requested_capacity is None
            else requested_capacity
        )
        if capacity < 1 or capacity > MAX_MULTI_SESSION_CAPACITY:
            blockers.append(
                "multi-session capacity must be between 1 and "
                f"{MAX_MULTI_SESSION_CAPACITY}"
            )
    else:
        blockers.append(f"unsupported mode: {mode}")

    command: list[str] = []
    if not blockers:
        command = ["claude", "remote-control", "--sandbox"]
        if mode == "single":
            command.extend(["--spawn", "session", "--permission-mode", "default"])
        else:
            command.extend(
                [
                    "--spawn",
                    "worktree",
                    "--capacity",
                    str(capacity),
                    "--no-create-session-in-dir",
                    "--permission-mode",
                    "default",
                ]
            )

    return ServerPlan(
        status="ready" if command else "blocked",
        mode=mode,
        capacity=capacity,
        command=command,
        blockers=blockers,
        resource_policy={
            "ram_used_block_pct": RAM_USED_BLOCK_PCT,
            "ram_free_block_gb": RAM_FREE_BLOCK_GB,
            "disk_free_block_gb": DISK_FREE_BLOCK_GB,
            "max_multi_session_capacity": MAX_MULTI_SESSION_CAPACITY,
        },
    )


def render_markdown(plan: ServerPlan, resources: HostResources) -> str:
    command = " ".join(plan.command) if plan.command else "not generated"
    lines = [
        "# Claude Code Remote Control server plan",
        "",
        f"- Status: `{plan.status}`",
        f"- Mode: `{plan.mode}`",
        (
            "- Capacity: `"
            f"{plan.capacity if plan.capacity is not None else 'not applicable'}`"
        ),
        f"- RAM used/free: `{resources.ram_used_pct}% / {resources.ram_free_gb} GB`",
        f"- Disk free: `{resources.disk_free_gb} GB`",
        f"- Command: `{command}`",
    ]
    if plan.blockers:
        lines.extend(["", "## Blockers"])
        lines.extend(f"- {blocker}" for blocker in plan.blockers)
    lines.extend(
        [
            "",
            "This is a plan only. The script never starts Claude Code or changes settings.",
        ]
    )
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mode",
        choices=("single", "multi", "same-dir"),
        default="single",
    )
    parser.add_argument("--capacity", type=int)
    parser.add_argument("--security-review-recorded", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = Path.cwd().resolve()
    resources = current_resources(root)
    plan = build_server_plan(
        mode=args.mode,
        requested_capacity=args.capacity,
        security_review_recorded=args.security_review_recorded,
        resources=resources,
    )
    if args.json:
        payload: dict[str, Any] = asdict(plan)
        payload["resources"] = asdict(resources)
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    else:
        print(render_markdown(plan, resources))
    return 0 if plan.status == "ready" else 2


if __name__ == "__main__":
    raise SystemExit(main())
