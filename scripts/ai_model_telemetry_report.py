#!/usr/bin/env python3
"""Summarize AI model usage telemetry for monthly model reviews.

The reporter is intentionally offline-only. It reads JSON/JSONL event files,
aggregates cost, quality, latency, and failure signals, and emits artifacts that
can be attached to #2522 monthly review comments. It never calls provider APIs.
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = 1
SUCCESS_STATUSES = {"success", "ok", "completed"}
FAILURE_STATUSES = {"error", "failed", "timeout", "rate_limited", "blocked"}
SENSITIVE_EVENT_KEYS = {
    "prompt",
    "response",
    "completion",
    "raw_request",
    "raw_response",
    "api_key",
    "secret",
    "token",
    "account_number",
    "asset_balance",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def load_events(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(path)
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        return []

    if path.suffix.lower() == ".jsonl":
        events: list[dict[str, Any]] = []
        for index, line in enumerate(text.splitlines(), start=1):
            if not line.strip():
                continue
            value = json.loads(line)
            if not isinstance(value, dict):
                raise ValueError(f"{path}:{index}: each JSONL row must be an object")
            events.append(value)
        return events

    value = json.loads(text)
    if isinstance(value, list):
        return [event for event in value if isinstance(event, dict)]
    if isinstance(value, dict) and isinstance(value.get("events"), list):
        return [event for event in value["events"] if isinstance(event, dict)]
    raise ValueError(f"{path}: expected a JSON list, JSONL rows, or an object with events")


def clean_text(value: Any, fallback: str = "unknown") -> str:
    text = str(value or "").strip()
    return text if text else fallback


def number(value: Any) -> float | None:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip())
    except ValueError:
        return None


def int_number(value: Any) -> int | None:
    parsed = number(value)
    if parsed is None:
        return None
    return int(parsed)


def p95(values: list[float]) -> float | None:
    if not values:
        return None
    if len(values) == 1:
        return values[0]
    ordered = sorted(values)
    index = int(round((len(ordered) - 1) * 0.95))
    return ordered[index]


def detect_sensitive_keys(event: dict[str, Any]) -> list[str]:
    found: list[str] = []
    stack: list[tuple[str, Any]] = [("", event)]
    while stack:
        prefix, value = stack.pop()
        if isinstance(value, dict):
            for key, nested in value.items():
                full_key = f"{prefix}.{key}" if prefix else str(key)
                if str(key).lower() in SENSITIVE_EVENT_KEYS:
                    found.append(full_key)
                stack.append((full_key, nested))
        elif isinstance(value, list):
            for index, nested in enumerate(value):
                stack.append((f"{prefix}[{index}]", nested))
    return sorted(set(found))


def canonical_event(raw: dict[str, Any], index: int) -> dict[str, Any]:
    status = clean_text(raw.get("status"), "unknown").lower()
    return {
        "event_id": clean_text(raw.get("event_id") or raw.get("id"), f"event-{index}"),
        "occurred_at": clean_text(raw.get("occurred_at") or raw.get("created_at"), "unknown"),
        "provider": clean_text(raw.get("provider")),
        "model": clean_text(raw.get("model")),
        "task_type": clean_text(raw.get("task_type")),
        "feature": clean_text(raw.get("feature"), "unspecified"),
        "status": status,
        "latency_ms": number(raw.get("latency_ms")),
        "estimated_cost_usd": number(
            raw.get("estimated_cost_usd")
            if raw.get("estimated_cost_usd") is not None
            else raw.get("cost_usd")
        ),
        "input_tokens": int_number(raw.get("input_tokens")),
        "output_tokens": int_number(raw.get("output_tokens")),
        "thinking_tokens": int_number(raw.get("thinking_tokens")),
        "quality_score": number(raw.get("quality_score")),
        "issue": clean_text(raw.get("issue"), ""),
        "source": clean_text(raw.get("source"), "manual"),
        "sensitive_keys": detect_sensitive_keys(raw),
    }


def group_key(event: dict[str, Any]) -> tuple[str, str, str]:
    return (event["provider"], event["model"], event["task_type"])


def summarize_group(events: list[dict[str, Any]]) -> dict[str, Any]:
    costs = [event["estimated_cost_usd"] for event in events if event["estimated_cost_usd"] is not None]
    latencies = [event["latency_ms"] for event in events if event["latency_ms"] is not None]
    quality_scores = [event["quality_score"] for event in events if event["quality_score"] is not None]
    statuses = [event["status"] for event in events]
    failures = [status for status in statuses if status in FAILURE_STATUSES]
    successes = [status for status in statuses if status in SUCCESS_STATUSES]

    return {
        "provider": events[0]["provider"],
        "model": events[0]["model"],
        "task_type": events[0]["task_type"],
        "event_count": len(events),
        "success_count": len(successes),
        "failure_count": len(failures),
        "failure_rate": round(len(failures) / len(events), 4) if events else 0.0,
        "estimated_cost_usd": round(sum(costs), 6),
        "avg_latency_ms": round(statistics.mean(latencies), 2) if latencies else None,
        "p95_latency_ms": round(p95(latencies), 2) if latencies else None,
        "avg_quality_score": round(statistics.mean(quality_scores), 3) if quality_scores else None,
        "input_tokens": sum(event["input_tokens"] or 0 for event in events),
        "output_tokens": sum(event["output_tokens"] or 0 for event in events),
        "thinking_tokens": sum(event["thinking_tokens"] or 0 for event in events),
        "features": sorted({event["feature"] for event in events if event["feature"]}),
    }


def build_alerts(
    groups: list[dict[str, Any]],
    events: list[dict[str, Any]],
    *,
    cost_alert_usd: float,
    failure_rate_alert: float,
    min_events_for_failure_alert: int,
    latency_alert_ms: float,
) -> list[dict[str, Any]]:
    alerts: list[dict[str, Any]] = []
    for group in groups:
        label = f"{group['provider']}/{group['model']}:{group['task_type']}"
        if group["estimated_cost_usd"] >= cost_alert_usd:
            alerts.append(
                {
                    "severity": "warning",
                    "label": label,
                    "reason": "cost_threshold",
                    "message": (
                        f"Estimated cost ${group['estimated_cost_usd']:.4f} "
                        f">= ${cost_alert_usd:.2f} threshold."
                    ),
                }
            )
        if (
            group["event_count"] >= min_events_for_failure_alert
            and group["failure_rate"] >= failure_rate_alert
        ):
            alerts.append(
                {
                    "severity": "warning",
                    "label": label,
                    "reason": "failure_rate_threshold",
                    "message": (
                        f"Failure rate {group['failure_rate']:.1%} "
                        f">= {failure_rate_alert:.0%} threshold."
                    ),
                }
            )
        if (
            group["p95_latency_ms"] is not None
            and group["p95_latency_ms"] >= latency_alert_ms
        ):
            alerts.append(
                {
                    "severity": "warning",
                    "label": label,
                    "reason": "latency_threshold",
                    "message": (
                        f"P95 latency {group['p95_latency_ms']:.0f}ms "
                        f">= {latency_alert_ms:.0f}ms threshold."
                    ),
                }
            )

    for event in events:
        if event["sensitive_keys"]:
            alerts.append(
                {
                    "severity": "blocker",
                    "label": event["event_id"],
                    "reason": "sensitive_payload_key",
                    "message": (
                        "Telemetry event includes forbidden raw/sensitive keys: "
                        + ", ".join(event["sensitive_keys"])
                    ),
                }
            )
    return alerts


def build_report(
    raw_events: Iterable[dict[str, Any]],
    *,
    cost_alert_usd: float = 10.0,
    failure_rate_alert: float = 0.2,
    min_events_for_failure_alert: int = 3,
    latency_alert_ms: float = 30000.0,
) -> dict[str, Any]:
    events = [canonical_event(event, index) for index, event in enumerate(raw_events, start=1)]
    grouped: dict[tuple[str, str, str], list[dict[str, Any]]] = defaultdict(list)
    for event in events:
        grouped[group_key(event)].append(event)

    groups = [summarize_group(group_events) for group_events in grouped.values()]
    groups.sort(key=lambda item: (item["provider"], item["model"], item["task_type"]))

    total_cost = round(sum(group["estimated_cost_usd"] for group in groups), 6)
    total_failures = sum(group["failure_count"] for group in groups)
    total_events = len(events)
    report = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": utc_now(),
        "issue": "#2522",
        "live_provider_calls": False,
        "event_count": total_events,
        "group_count": len(groups),
        "total_estimated_cost_usd": total_cost,
        "total_failure_rate": round(total_failures / total_events, 4) if total_events else 0.0,
        "thresholds": {
            "cost_alert_usd": cost_alert_usd,
            "failure_rate_alert": failure_rate_alert,
            "min_events_for_failure_alert": min_events_for_failure_alert,
            "latency_alert_ms": latency_alert_ms,
        },
        "groups": groups,
        "alerts": build_alerts(
            groups,
            events,
            cost_alert_usd=cost_alert_usd,
            failure_rate_alert=failure_rate_alert,
            min_events_for_failure_alert=min_events_for_failure_alert,
            latency_alert_ms=latency_alert_ms,
        ),
    }
    return report


def render_money(value: float) -> str:
    return f"${value:.4f}"


def render_optional(value: Any, suffix: str = "") -> str:
    if value is None:
        return "n/a"
    if isinstance(value, float):
        return f"{value:.2f}{suffix}"
    return f"{value}{suffix}"


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# AI Model Telemetry Monthly Review",
        "",
        f"- Generated: `{report['generated_at']}`",
        f"- Issue: `{report['issue']}`",
        f"- Live provider calls: {'enabled' if report['live_provider_calls'] else 'disabled'}",
        f"- Events: {report['event_count']}",
        f"- Total estimated cost: {render_money(report['total_estimated_cost_usd'])}",
        f"- Total failure rate: {report['total_failure_rate']:.1%}",
        "",
        "## Groups",
        "",
        "| Provider | Model | Task | Events | Failure Rate | Cost | Avg Latency | P95 Latency | Avg Quality |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for group in report["groups"]:
        lines.append(
            "| {provider} | {model} | {task_type} | {event_count} | {failure_rate:.1%} | {cost} | {avg_latency} | {p95_latency} | {quality} |".format(
                provider=group["provider"],
                model=group["model"],
                task_type=group["task_type"],
                event_count=group["event_count"],
                failure_rate=group["failure_rate"],
                cost=render_money(group["estimated_cost_usd"]),
                avg_latency=render_optional(group["avg_latency_ms"], "ms"),
                p95_latency=render_optional(group["p95_latency_ms"], "ms"),
                quality=render_optional(group["avg_quality_score"]),
            )
        )

    lines.extend(["", "## Alerts", ""])
    if report["alerts"]:
        for alert in report["alerts"]:
            lines.append(
                f"- **{alert['severity']}** `{alert['reason']}` {alert['label']}: {alert['message']}"
            )
    else:
        lines.append("- No alerts.")

    lines.extend(
        [
            "",
            "## Review Policy",
            "",
            "- This report is telemetry-only and does not rank a fixed strongest model.",
            "- Routing changes must cite scored #2520 bench evidence or remain feature-flagged.",
            "- Telemetry events must not store raw prompts, responses, secrets, account numbers, or asset balances.",
        ]
    )
    return "\n".join(lines) + "\n"


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="JSON or JSONL telemetry events")
    parser.add_argument("--output-json", type=Path, help="Path for machine-readable summary")
    parser.add_argument("--output-md", type=Path, help="Path for Markdown summary")
    parser.add_argument("--cost-alert-usd", type=float, default=10.0)
    parser.add_argument("--failure-rate-alert", type=float, default=0.2)
    parser.add_argument("--min-events-for-failure-alert", type=int, default=3)
    parser.add_argument("--latency-alert-ms", type=float, default=30000.0)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when blocker alerts are present.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    events = load_events(args.input)
    report = build_report(
        events,
        cost_alert_usd=args.cost_alert_usd,
        failure_rate_alert=args.failure_rate_alert,
        min_events_for_failure_alert=args.min_events_for_failure_alert,
        latency_alert_ms=args.latency_alert_ms,
    )

    if args.output_json:
        write_json(args.output_json, report)
    if args.output_md:
        write_text(args.output_md, render_markdown(report))

    if not args.output_json and not args.output_md:
        print(json.dumps(report, ensure_ascii=False, indent=2))

    if args.strict and any(alert["severity"] == "blocker" for alert in report["alerts"]):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
