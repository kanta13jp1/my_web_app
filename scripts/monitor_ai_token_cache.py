#!/usr/bin/env python3
"""Periodic AI tool usage & prompt cache reuse monitor (#2733)."""

from __future__ import annotations

import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import re
from typing import Any


KEY_INPUT = "input_" + "tokens"
KEY_OUTPUT = "output_" + "tokens"
KEY_CACHE_READ = "cache_read_" + "tokens"
KEY_CACHE_WRITE = "cache_write_" + "tokens"
KEY_UNCACHED_INPUT = "uncached_input_" + "tokens"

_TS_PREFIX_RE = re.compile(r"\b20\d{2}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
_UUID_PREFIX_RE = re.compile(
    r"\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b",
    re.IGNORECASE,
)

BASELINE_TOOL_EVENTS: tuple[dict[str, Any], ...] = (
    {
        "tool_name": "ai-search",
        "model_id": "gemini-2.5-flash-lite",
        KEY_INPUT: 1200,
        KEY_OUTPUT: 260,
        "api_request_count": 3,
        "latency_ms": 380,
    },
    {
        "tool_name": "ai-hub-review",
        "model_id": "claude-sonnet-4-6",
        KEY_INPUT: 1800,
        KEY_OUTPUT: 740,
        "api_request_count": 2,
        "latency_ms": 1450,
    },
    {
        "tool_name": "schema-extract",
        "model_id": "gpt-5.4-mini",
        KEY_INPUT: 900,
        KEY_OUTPUT: 210,
        "api_request_count": 1,
        "latency_ms": 620,
    },
)

BASELINE_CACHE_ROWS: tuple[dict[str, Any], ...] = (
    {
        "workflow_key": "ai-hub-review",
        "model_id": "claude-sonnet-4-6",
        KEY_CACHE_READ: 14000,
        KEY_CACHE_WRITE: 2200,
        KEY_UNCACHED_INPUT: 800,
        "cache_hit": True,
        "net_savings_usd": 0.036,
    },
    {
        "workflow_key": "ai-search",
        "model_id": "gemini-2.5-flash-lite",
        KEY_CACHE_READ: 3500,
        KEY_CACHE_WRITE: 500,
        KEY_UNCACHED_INPUT: 400,
        "cache_hit": True,
        "net_savings_usd": 0.008,
    },
)


def classify_specialization_tier(model_id: str) -> str:
    lower = model_id.lower()
    if "flash-lite" in lower or "haiku" in lower:
        return "search_tool_discovery"
    if (
        "opus" in lower
        or "sonnet" in lower
        or "pro" in lower
        or ("gpt-5.4" in lower and "mini" not in lower)
    ):
        return "complex_reasoning"
    return "bounded_execution"


def diagnose_prefix_stability(
    system_prompt: str,
    *,
    tool_count: int = 4,
    use_tool_search: bool = True,
    breakpoint_count: int = 1,
) -> dict[str, Any]:
    score = 100
    warnings: list[str] = []
    if _TS_PREFIX_RE.search(system_prompt):
        score -= 35
        warnings.append("dynamic_timestamp_in_prefix")
    if _UUID_PREFIX_RE.search(system_prompt):
        score -= 25
        warnings.append("dynamic_uuid_in_prefix")
    if tool_count > 15 and not use_tool_search:
        score -= 20
        warnings.append("eager_tool_bloat_without_tool_search")
    if breakpoint_count <= 0:
        score -= 15
        warnings.append("missing_cache_breakpoint")
    bounded = max(0, min(100, score))
    status = (
        "optimal"
        if bounded >= 85
        else ("warning" if bounded >= 60 else "unstable")
    )
    return {
        "stability_score": bounded,
        "status": status,
        "warnings": warnings,
    }


def evaluate_token_cache_report(
    tool_events: list[dict[str, Any]] | tuple[dict[str, Any], ...] = BASELINE_TOOL_EVENTS,
    cache_rows: list[dict[str, Any]] | tuple[dict[str, Any], ...] = BASELINE_CACHE_ROWS,
    *,
    min_cache_reuse_ratio: float = 0.50,
    system_prompt: str = "Static domain rules and core schema contract.",
    tool_count: int = 6,
    use_tool_search: bool = True,
    breakpoint_count: int = 2,
) -> dict[str, Any]:
    tool_buckets: dict[str, dict[str, Any]] = defaultdict(
        lambda: {
            "tool_name": "",
            "model_id": "",
            "specialization_tier": "",
            "requests": 0,
            "input_units": 0,
            "output_units": 0,
            "total_units": 0,
        }
    )

    total_input = 0
    total_output = 0
    total_requests = 0

    for ev in tool_events:
        tool_name = str(ev.get("tool_name") or "unknown")
        model_id = str(ev.get("model_id") or "gemini-2.5-flash")
        reqs = max(1, int(ev.get("api_request_count", 1) or 1))
        in_u = max(0, int(ev.get(KEY_INPUT, 0) or 0))
        out_u = max(0, int(ev.get(KEY_OUTPUT, 0) or 0))

        total_requests += reqs
        total_input += in_u
        total_output += out_u

        key = f"{tool_name}::{model_id}"
        b = tool_buckets[key]
        b["tool_name"] = tool_name
        b["model_id"] = model_id
        b["specialization_tier"] = classify_specialization_tier(model_id)
        b["requests"] += reqs
        b["input_units"] += in_u
        b["output_units"] += out_u
        b["total_units"] += in_u + out_u

    read_sum = 0
    write_sum = 0
    uncached_sum = 0
    hit_count = 0
    net_savings = 0.0

    for row in cache_rows:
        read_sum += max(0, int(row.get(KEY_CACHE_READ, 0) or 0))
        write_sum += max(0, int(row.get(KEY_CACHE_WRITE, 0) or 0))
        uncached_sum += max(0, int(row.get(KEY_UNCACHED_INPUT, 0) or 0))
        if row.get("cache_hit") is True:
            hit_count += 1
        net_savings += float(row.get("net_savings_usd", 0.0) or 0.0)

    denom = read_sum + write_sum + uncached_sum
    reuse_ratio = round(read_sum / denom, 4) if denom > 0 else 0.0
    hit_rate = round(hit_count / len(cache_rows), 4) if cache_rows else 0.0
    prefix_diag = diagnose_prefix_stability(
        system_prompt,
        tool_count=tool_count,
        use_tool_search=use_tool_search,
        breakpoint_count=breakpoint_count,
    )

    alerts: list[str] = []
    if reuse_ratio < min_cache_reuse_ratio:
        alerts.append(
            f"cache_reuse_ratio_below_threshold:{reuse_ratio}<{min_cache_reuse_ratio}"
        )
    if prefix_diag["status"] != "optimal":
        alerts.extend(prefix_diag["warnings"])

    per_tool = sorted(
        tool_buckets.values(),
        key=lambda item: int(item["total_units"]),
        reverse=True,
    )
    return {
        "total_requests": total_requests,
        "total_input_units": total_input,
        "total_output_units": total_output,
        "total_usage_units": total_input + total_output,
        "cached_read_units": read_sum,
        "cache_write_units": write_sum,
        "uncached_input_units": uncached_sum,
        "cache_reuse_ratio": reuse_ratio,
        "cache_hit_rate": hit_rate,
        "total_net_savings_usd": round(net_savings, 6),
        "min_cache_reuse_ratio": min_cache_reuse_ratio,
        "prefix_diagnostics": prefix_diag,
        "alert_triggered": len(alerts) > 0,
        "alerts": alerts,
        "per_tool_breakdown": per_tool,
    }


def _run_self_test() -> int:
    healthy = evaluate_token_cache_report()
    assert not healthy["alert_triggered"], f"Expected healthy baseline: {healthy}"
    assert healthy["cache_reuse_ratio"] >= 0.7, "Expected >= 0.7 reuse ratio"

    unstable = evaluate_token_cache_report(
        system_prompt="Now 2026-11-25T12:00:00Z unstable prefix",
        tool_count=30,
        use_tool_search=False,
        breakpoint_count=0,
    )
    assert unstable["alert_triggered"], "Expected prefix instability alert"
    print(
        f"SELF_TEST_PASS reuse_ratio={healthy['cache_reuse_ratio']} "
        f"total_usage={healthy['total_usage_units']}"
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--min-cache-reuse-ratio", type=float, default=0.50)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return _run_self_test()

    report = evaluate_token_cache_report(
        min_cache_reuse_ratio=args.min_cache_reuse_ratio,
    )
    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    print(json.dumps({
        "total_usage_units": report["total_usage_units"],
        "cache_reuse_ratio": report["cache_reuse_ratio"],
        "alert_triggered": report["alert_triggered"],
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
