#!/usr/bin/env python3
"""Aggregate production observability signals without ingesting payloads."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

RESOURCE_PATTERN = re.compile(
    r"(?:cpu|load|memory|disk|io|wal|connection|numbackends|query)", re.I
)
METRIC_LINE = re.compile(
    r"^([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{[^}]*\})?\s+"
    r"([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)$"
)


def _number(value: Any, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def load_ai_hub(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    providers = data.get("providers", []) if isinstance(data, dict) else []
    return [row for row in providers if isinstance(row, dict)]


def load_sentry_count(path: Path) -> int:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, list):
        return sum(int(_number(row[1])) for row in data if isinstance(row, list) and len(row) > 1)
    if not isinstance(data, dict):
        return 0
    groups = data.get("groups")
    if isinstance(groups, list):
        return sum(
            int(_number(group.get("totals", {}).get("sum(quantity)")))
            for group in groups
            if isinstance(group, dict)
        )
    return int(_number(data.get("total", 0)))


def load_resource_metrics(path: Path) -> dict[str, float]:
    totals: dict[str, float] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = METRIC_LINE.match(line)
        if match and RESOURCE_PATTERN.search(match[1]):
            totals[match[1]] = totals.get(match[1], 0.0) + float(match[2])
    return dict(sorted(totals.items()))


def build_report(
    providers: list[dict[str, Any]],
    resources: dict[str, float],
    sentry_errors: int,
    *,
    p95_alert_ms: float,
    error_rate_alert: float,
    sentry_error_alert: int,
    resource_alerts: dict[str, float],
) -> dict[str, Any]:
    alerts: list[dict[str, Any]] = []
    summarized_providers = []
    for row in providers:
        total = int(_number(row.get("total_requests")))
        errors = int(_number(row.get("error_count")))
        error_rate = errors / total if total else 0.0
        p95 = _number(row.get("p95_latency_ms"))
        provider = str(row.get("provider") or "unknown")
        summary = {
            "provider": provider,
            "requests": total,
            "errors": errors,
            "error_rate": round(error_rate, 4),
            "p95_latency_ms": round(p95, 2),
        }
        summarized_providers.append(summary)
        if p95 >= p95_alert_ms:
            alerts.append({"source": "ai_hub", "reason": "p95_latency", "label": provider})
        if total > 0 and error_rate >= error_rate_alert:
            alerts.append({"source": "ai_hub", "reason": "error_rate", "label": provider})

    if sentry_errors >= sentry_error_alert:
        alerts.append({"source": "sentry", "reason": "error_volume", "label": "project"})
    for name, maximum in resource_alerts.items():
        if resources.get(name, 0.0) >= maximum:
            alerts.append({"source": "supabase_metrics", "reason": "resource", "label": name})

    fingerprint = "|".join(
        sorted(f"{item['source']}:{item['reason']}:{item['label']}" for item in alerts)
    )
    return {
        "schema_version": 1,
        "sources": {
            "ai_hub": "provider_health_view (24h aggregate)",
            "supabase": "Prometheus Metrics API",
            "sentry": "project received-error stats (24h aggregate)",
        },
        "providers": summarized_providers,
        "resources": resources,
        "sentry_errors_24h": sentry_errors,
        "thresholds": {
            "p95_alert_ms": p95_alert_ms,
            "error_rate_alert": error_rate_alert,
            "sentry_error_alert": sentry_error_alert,
            "resource_alerts": resource_alerts,
        },
        "alerts": alerts,
        "breach": bool(alerts),
        "dedupe_key": hashlib.sha256(fingerprint.encode()).hexdigest()[:16] if alerts else "none",
        "privacy": "aggregate identifiers and counters only; no prompts, responses, request bodies, or secrets",
    }


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Production Observability Monitor",
        "",
        f"- Threshold breach: **{str(report['breach']).lower()}**",
        f"- Sentry errors (24h): **{report['sentry_errors_24h']}**",
        f"- Dedupe key: `{report['dedupe_key']}`",
        "",
        "## AI Hub latency and errors",
        "",
        "| Provider | Requests | Errors | Error rate | P95 latency |",
        "| --- | ---: | ---: | ---: | ---: |",
    ]
    for row in report["providers"]:
        lines.append(
            f"| {row['provider']} | {row['requests']} | {row['errors']} | "
            f"{row['error_rate']:.1%} | {row['p95_latency_ms']:.0f}ms |"
        )
    lines.extend(["", "## Supabase resource signals", ""])
    for name, value in report["resources"].items():
        lines.append(f"- `{name}`: `{value:g}`")
    lines.extend(["", "## Alerts", ""])
    lines.extend(
        f"- `{a['source']}/{a['reason']}`: {a['label']}" for a in report["alerts"]
    )
    if not report["alerts"]:
        lines.append("- None")
    lines.extend(["", f"> Privacy: {report['privacy']}", ""])
    return "\n".join(lines)


def parse_resource_alerts(values: list[str]) -> dict[str, float]:
    result = {}
    for value in values:
        name, separator, maximum = value.partition("=")
        if not separator or not name:
            raise ValueError(f"invalid resource alert: {value}")
        result[name] = float(maximum)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ai-hub-json", type=Path, required=True)
    parser.add_argument("--supabase-metrics", type=Path, required=True)
    parser.add_argument("--sentry-json", type=Path, required=True)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--output-md", type=Path, required=True)
    parser.add_argument("--p95-alert-ms", type=float, default=5000)
    parser.add_argument("--error-rate-alert", type=float, default=0.2)
    parser.add_argument("--sentry-error-alert", type=int, default=20)
    parser.add_argument("--resource-alert", action="append", default=[])
    args = parser.parse_args(argv)
    report = build_report(
        load_ai_hub(args.ai_hub_json),
        load_resource_metrics(args.supabase_metrics),
        load_sentry_count(args.sentry_json),
        p95_alert_ms=args.p95_alert_ms,
        error_rate_alert=args.error_rate_alert,
        sentry_error_alert=args.sentry_error_alert,
        resource_alerts=parse_resource_alerts(args.resource_alert),
    )
    args.output_json.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    args.output_md.write_text(render_markdown(report), encoding="utf-8", newline="\n")
    print(f"breach={str(report['breach']).lower()}")
    print(f"dedupe_key={report['dedupe_key']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
