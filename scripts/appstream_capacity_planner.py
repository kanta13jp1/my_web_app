#!/usr/bin/env python3
"""Capacity & cost comparison planner for multi-session fleets (#2797)."""

from __future__ import annotations

import argparse
from dataclasses import asdict, dataclass
import json
import math
import sys


@dataclass(frozen=True)
class InstanceProfile:
    instance_type: str
    vcpu: float
    memory_gib: float
    hourly_cost_usd: float


@dataclass(frozen=True)
class SessionWorkload:
    per_session_vcpu: float
    per_session_memory_gib: float
    cpu_headroom_ratio: float = 0.8
    memory_headroom_ratio: float = 0.8
    configured_max_sessions: int = 10
    requires_webcam: bool = False
    requires_local_usb: bool = False


@dataclass(frozen=True)
class CapacityPlanResult:
    instance_type: str
    cpu_bound_sessions: int
    memory_bound_sessions: int
    recommended_max_sessions: int
    single_session_cost_per_user_usd: float
    multi_session_cost_per_user_usd: float
    cost_savings_ratio: float
    client_ui_notices: list[str]


def plan_multisession_capacity(
    profile: InstanceProfile,
    workload: SessionWorkload,
) -> CapacityPlanResult:
    """Compute safe max concurrent sessions and per-user cost comparison."""
    if profile.vcpu <= 0 or profile.memory_gib <= 0:
        raise ValueError("Instance vcpu and memory_gib must be positive.")
    if profile.hourly_cost_usd < 0:
        raise ValueError("hourly_cost_usd cannot be negative.")
    if workload.per_session_vcpu <= 0 or workload.per_session_memory_gib <= 0:
        raise ValueError("Per-session vcpu and memory_gib must be positive.")
    if not (0 < workload.cpu_headroom_ratio <= 1.0):
        raise ValueError("cpu_headroom_ratio must be in (0, 1].")
    if not (0 < workload.memory_headroom_ratio <= 1.0):
        raise ValueError("memory_headroom_ratio must be in (0, 1].")
    if workload.configured_max_sessions <= 0:
        raise ValueError("configured_max_sessions must be positive.")

    usable_vcpu = profile.vcpu * workload.cpu_headroom_ratio
    usable_mem = profile.memory_gib * workload.memory_headroom_ratio

    cpu_bound = math.floor(usable_vcpu / workload.per_session_vcpu)
    mem_bound = math.floor(usable_mem / workload.per_session_memory_gib)
    recommended = max(
        0,
        min(cpu_bound, mem_bound, workload.configured_max_sessions),
    )

    single_cost = profile.hourly_cost_usd
    if recommended > 0:
        multi_cost = round(profile.hourly_cost_usd / recommended, 4)
        savings = (
            0.0
            if single_cost == 0
            else round(1.0 - (multi_cost / single_cost), 4)
        )
    else:
        multi_cost = single_cost
        savings = 0.0

    notices: list[str] = []
    if workload.requires_webcam:
        notices.append(
            "UI notice required: verify webcam redirection support before "
            "enabling multi-session streaming."
        )
    if workload.requires_local_usb:
        notices.append(
            "UI notice required: verify local USB peripheral redirection "
            "support in target client."
        )

    return CapacityPlanResult(
        instance_type=profile.instance_type,
        cpu_bound_sessions=cpu_bound,
        memory_bound_sessions=mem_bound,
        recommended_max_sessions=recommended,
        single_session_cost_per_user_usd=round(single_cost, 4),
        multi_session_cost_per_user_usd=multi_cost,
        cost_savings_ratio=savings,
        client_ui_notices=notices,
    )


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plan multi-session instance capacity and cost savings.",
    )
    parser.add_argument("--instance-type", default="stream.standard.large")
    parser.add_argument("--vcpu", type=float, default=2.0)
    parser.add_argument("--memory-gib", type=float, default=8.0)
    parser.add_argument("--hourly-cost-usd", type=float, default=0.20)
    parser.add_argument("--session-vcpu", type=float, default=0.4)
    parser.add_argument("--session-memory-gib", type=float, default=1.5)
    parser.add_argument("--max-sessions", type=int, default=8)
    parser.add_argument("--requires-webcam", action="store_true")
    parser.add_argument("--requires-local-usb", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv if argv is not None else sys.argv[1:])
    result = plan_multisession_capacity(
        InstanceProfile(
            instance_type=args.instance_type,
            vcpu=args.vcpu,
            memory_gib=args.memory_gib,
            hourly_cost_usd=args.hourly_cost_usd,
        ),
        SessionWorkload(
            per_session_vcpu=args.session_vcpu,
            per_session_memory_gib=args.session_memory_gib,
            configured_max_sessions=args.max_sessions,
            requires_webcam=args.requires_webcam,
            requires_local_usb=args.requires_local_usb,
        ),
    )
    if args.json:
        print(json.dumps(asdict(result), ensure_ascii=False, indent=2))
    else:
        print(
            f"{result.instance_type}: max_sessions={result.recommended_max_sessions} "
            f"savings={result.cost_savings_ratio:.2%}"
        )
    return 0 if result.recommended_max_sessions > 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
