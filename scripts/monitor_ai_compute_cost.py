#!/usr/bin/env python3
"""AI compute & GPU cost telemetry evaluator and threshold alerter (#2658).

Computes estimated compute & token costs in USD using a configurable rate card,
aggregates daily/monthly totals and per-user utilization frequency, evaluates
system-wide cost thresholds, and sends alerts via SSRF-pinned HTTPS in live mode.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
from dataclasses import asdict, dataclass
import http.client
import ipaddress
import json
from pathlib import Path
import socket
import ssl
import urllib.parse


DEFAULT_DAILY_THRESHOLD_USD = 50.0
DEFAULT_MONTHLY_THRESHOLD_USD = 500.0
COST_ESTIMATE_DISCLAIMER = (
    "Estimated compute and API costs in USD derived from configurable internal GPU/token rates; "
    "these estimates are operational telemetry and not official cloud billing invoices."
)
_CGNAT_NET = ipaddress.ip_network("100.64.0.0/10")


@dataclass(frozen=True)
class GpuRateSpec:
    gpu_profile: str
    per_second_usd: float
    per_1k_input_usd: float
    per_1k_output_usd: float


DEFAULT_GPU_RATE_CARD: dict[str, GpuRateSpec] = {
    "cpu-fallback": GpuRateSpec("cpu-fallback", 0.00005, 0.0002, 0.0006),
    "t4-inference": GpuRateSpec("t4-inference", 0.00018, 0.0003, 0.0009),
    "l4-inference": GpuRateSpec("l4-inference", 0.00035, 0.0005, 0.0015),
    "a100-cluster": GpuRateSpec("a100-cluster", 0.00120, 0.0010, 0.0030),
    "h100-cluster": GpuRateSpec("h100-cluster", 0.00240, 0.0015, 0.0045),
    "managed-api": GpuRateSpec("managed-api", 0.00010, 0.0004, 0.0012),
}


@dataclass(frozen=True)
class ComputeTelemetryEvent:
    user_id: str
    tool_name: str
    gpu_profile: str
    model_id: str
    input_tokens: int
    output_tokens: int
    api_request_count: int
    latency_ms: int
    recorded_date: str


SAMPLE_BASELINE_EVENTS: tuple[ComputeTelemetryEvent, ...] = (
    ComputeTelemetryEvent(
        user_id="usr-alpha",
        tool_name="ai-hub",
        gpu_profile="l4-inference",
        model_id="gemini-2.5-flash",
        input_tokens=1800,
        output_tokens=620,
        api_request_count=2,
        latency_ms=840,
        recorded_date="2026-11-24",
    ),
    ComputeTelemetryEvent(
        user_id="usr-alpha",
        tool_name="ai-search",
        gpu_profile="t4-inference",
        model_id="gemini-2.5-flash",
        input_tokens=1200,
        output_tokens=310,
        api_request_count=1,
        latency_ms=420,
        recorded_date="2026-11-24",
    ),
    ComputeTelemetryEvent(
        user_id="usr-beta",
        tool_name="ai-writing-assistant",
        gpu_profile="a100-cluster",
        model_id="claude-sonnet",
        input_tokens=4500,
        output_tokens=1800,
        api_request_count=3,
        latency_ms=2150,
        recorded_date="2026-11-23",
    ),
)


def estimate_event_cost_usd(
    event: ComputeTelemetryEvent,
    rate_card: dict[str, GpuRateSpec] | None = None,
) -> float:
    card = rate_card or DEFAULT_GPU_RATE_CARD
    spec = card.get(event.gpu_profile) or card["managed-api"]
    gpu_seconds = (max(0, event.latency_ms) / 1000.0) * max(1, event.api_request_count)
    compute_cost = gpu_seconds * spec.per_second_usd
    token_cost = (
        (max(0, event.input_tokens) / 1000.0) * spec.per_1k_input_usd
        + (max(0, event.output_tokens) / 1000.0) * spec.per_1k_output_usd
    )
    return round(compute_cost + token_cost, 6)


def evaluate_compute_cost_report(
    events: tuple[ComputeTelemetryEvent, ...] = SAMPLE_BASELINE_EVENTS,
    *,
    daily_threshold_usd: float = DEFAULT_DAILY_THRESHOLD_USD,
    monthly_threshold_usd: float = DEFAULT_MONTHLY_THRESHOLD_USD,
    target_date: str | None = None,
    rate_card: dict[str, GpuRateSpec] | None = None,
) -> dict[str, object]:
    if daily_threshold_usd <= 0:
        raise ValueError("daily_threshold_usd must be positive")
    if monthly_threshold_usd < daily_threshold_usd:
        raise ValueError("monthly_threshold_usd must be >= daily_threshold_usd")

    daily_totals: dict[str, dict[str, float]] = defaultdict(
        lambda: {"requests": 0, "tokens": 0, "latency_sum": 0.0, "samples": 0, "cost_usd": 0.0}
    )
    monthly_totals: dict[str, dict[str, float]] = defaultdict(
        lambda: {"requests": 0, "tokens": 0, "latency_sum": 0.0, "samples": 0, "cost_usd": 0.0}
    )
    user_totals: dict[str, dict[str, float]] = defaultdict(
        lambda: {"requests": 0, "tokens": 0, "latency_sum": 0.0, "samples": 0, "cost_usd": 0.0}
    )

    total_cost = 0.0
    total_requests = 0
    total_tokens = 0
    latency_sum = 0.0

    for ev in events:
        cost = estimate_event_cost_usd(ev, rate_card=rate_card)
        tokens = max(0, ev.input_tokens) + max(0, ev.output_tokens)
        reqs = max(1, ev.api_request_count)
        lat = max(0, ev.latency_ms)
        month_key = ev.recorded_date[:7]

        for bucket in (daily_totals[ev.recorded_date], monthly_totals[month_key], user_totals[ev.user_id]):
            bucket["requests"] += reqs
            bucket["tokens"] += tokens
            bucket["latency_sum"] += lat
            bucket["samples"] += 1
            bucket["cost_usd"] = round(bucket["cost_usd"] + cost, 6)

        total_cost = round(total_cost + cost, 6)
        total_requests += reqs
        total_tokens += tokens
        latency_sum += lat

    sorted_days = sorted(daily_totals.keys())
    effective_day = target_date or (sorted_days[-1] if sorted_days else "")
    effective_month = effective_day[:7] if effective_day else ""

    latest_daily_cost = daily_totals[effective_day]["cost_usd"] if effective_day in daily_totals else 0.0
    latest_monthly_cost = (
        monthly_totals[effective_month]["cost_usd"] if effective_month in monthly_totals else 0.0
    )

    daily_exceeded = latest_daily_cost >= daily_threshold_usd
    monthly_exceeded = latest_monthly_cost >= monthly_threshold_usd
    alert_triggered = daily_exceeded or monthly_exceeded

    per_user_rows = [
        {
            "user_id": uid,
            "request_count": int(agg["requests"]),
            "total_tokens": int(agg["tokens"]),
            "avg_latency_ms": round(agg["latency_sum"] / agg["samples"], 1),
            "estimated_cost_usd": agg["cost_usd"],
        }
        for uid, agg in sorted(
            user_totals.items(),
            key=lambda kv: (-kv[1]["cost_usd"], kv[0]),
        )
    ]

    return {
        "disclaimer": COST_ESTIMATE_DISCLAIMER,
        "daily_threshold_usd": daily_threshold_usd,
        "monthly_threshold_usd": monthly_threshold_usd,
        "effective_date": effective_day,
        "effective_month": effective_month,
        "latest_daily_cost_usd": latest_daily_cost,
        "latest_monthly_cost_usd": latest_monthly_cost,
        "total_requests": total_requests,
        "total_tokens": total_tokens,
        "avg_latency_ms": round(latency_sum / len(events), 1) if events else 0.0,
        "total_estimated_cost_usd": total_cost,
        "daily_exceeded": daily_exceeded,
        "monthly_exceeded": monthly_exceeded,
        "threshold_alert_triggered": alert_triggered,
        "status": "alert" if alert_triggered else "ok",
        "daily_breakdown": {
            day: {
                "request_count": int(agg["requests"]),
                "total_tokens": int(agg["tokens"]),
                "avg_latency_ms": round(agg["latency_sum"] / agg["samples"], 1),
                "estimated_cost_usd": agg["cost_usd"],
            }
            for day, agg in sorted(daily_totals.items(), reverse=True)
        },
        "monthly_breakdown": {
            mon: {
                "request_count": int(agg["requests"]),
                "total_tokens": int(agg["tokens"]),
                "avg_latency_ms": round(agg["latency_sum"] / agg["samples"], 1),
                "estimated_cost_usd": agg["cost_usd"],
            }
            for mon, agg in sorted(monthly_totals.items(), reverse=True)
        },
        "user_utilization": per_user_rows,
    }


def _is_disallowed_ip(ip_str: str) -> bool:
    ip = ipaddress.ip_address(ip_str)
    if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped is not None:
        ip = ip.ipv4_mapped
    return (
        ip.is_private
        or ip.is_loopback
        or ip.is_link_local
        or ip.is_multicast
        or ip.is_reserved
        or ip.is_unspecified
        or (isinstance(ip, ipaddress.IPv4Address) and ip in _CGNAT_NET)
    )


def _sanitize_url_for_log(raw_url: str) -> str:
    parsed = urllib.parse.urlsplit(raw_url)
    host = parsed.hostname or "unknown"
    port = f":{parsed.port}" if parsed.port else ""
    return f"{parsed.scheme}://{host}{port}{parsed.path}"


def validate_and_resolve_https_url(url: str) -> tuple[urllib.parse.SplitResult, str]:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("Only explicit https URLs with a valid hostname are allowed")
    port = parsed.port or 443
    infos = socket.getaddrinfo(parsed.hostname, port, type=socket.SOCK_STREAM)
    pinned_ip = ""
    for info in infos:
        addr = info[4][0]
        if _is_disallowed_ip(addr):
            raise ValueError(
                f"Blocked outbound HTTPS target resolving to non-public address: {_sanitize_url_for_log(url)}"
            )
        if not pinned_ip:
            pinned_ip = addr
    if not pinned_ip:
        raise ValueError(f"Could not resolve public IP for {_sanitize_url_for_log(url)}")
    return parsed, pinned_ip


class _PinnedHTTPSConnection(http.client.HTTPSConnection):
    """HTTPSConnection connecting to a pinned public IP while verifying TLS SNI/Host."""

    def __init__(
        self,
        *,
        connect_ip: str,
        server_hostname: str,
        port: int,
        timeout: int,
        context: ssl.SSLContext,
    ) -> None:
        super().__init__(
            host=server_hostname,
            port=port,
            timeout=timeout,
            context=context,
        )
        self._connect_ip = connect_ip

    def connect(self) -> None:
        sock = socket.create_connection((self._connect_ip, self.port), self.timeout, self.source_address)
        if self._tunnel_host:
            self.sock = sock
            self._tunnel()
        self.sock = self._context.wrap_socket(sock, server_hostname=self.host)


def post_json_pinned_https(
    url: str,
    payload: dict[str, object],
    *,
    headers: dict[str, str] | None = None,
    timeout: int = 10,
) -> dict[str, object]:
    parsed, pinned_ip = validate_and_resolve_https_url(url)
    hostname = parsed.hostname or ""
    port = parsed.port or 443
    path = parsed.path or "/"
    if parsed.query:
        path = f"{path}?{parsed.query}"

    ctx = ssl.create_default_context()
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    ctx.verify_mode = ssl.CERT_REQUIRED
    ctx.check_hostname = True

    req_headers = {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Host": hostname if port == 443 else f"{hostname}:{port}",
    }
    if headers:
        req_headers.update(headers)

    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    conn = _PinnedHTTPSConnection(
        connect_ip=pinned_ip,
        server_hostname=hostname,
        port=port,
        timeout=timeout,
        context=ctx,
    )
    try:
        conn.request("POST", path, body=body, headers=req_headers)
        resp = conn.getresponse()
        raw_resp = resp.read().decode("utf-8", errors="replace")
        if 300 <= resp.status < 400:
            raise RuntimeError(
                f"Redirect blocked ({resp.status}) for {_sanitize_url_for_log(url)}"
            )
        if resp.status < 200 or resp.status >= 300:
            raise RuntimeError(
                f"HTTPS POST failed ({resp.status}) for {_sanitize_url_for_log(url)}"
            )
        if not raw_resp.strip():
            return {}
        loaded = json.loads(raw_resp)
        return loaded if isinstance(loaded, dict) else {"data": loaded}
    finally:
        conn.close()


def render_markdown_report(report: dict[str, object], *, mode: str) -> str:
    return "\n".join(
        [
            "### AI Compute & GPU Cost Telemetry Monitor (#2658)",
            f"- Mode: `{mode}`",
            f"- Status: `{report['status']}` (`threshold_alert_triggered={report['threshold_alert_triggered']}`)",
            f"- Daily Cost ({report['effective_date']}): `USD {report['latest_daily_cost_usd']}` / `USD {report['daily_threshold_usd']}`",
            f"- Monthly Cost ({report['effective_month']}): `USD {report['latest_monthly_cost_usd']}` / `USD {report['monthly_threshold_usd']}`",
            f"- Requests / Tokens / Avg Latency: `{report['total_requests']}` / `{report['total_tokens']}` / `{report['avg_latency_ms']} ms`",
            "",
        ]
    )


def run_self_test() -> dict[str, object]:
    normal = evaluate_compute_cost_report(
        daily_threshold_usd=50.0,
        monthly_threshold_usd=500.0,
    )
    if normal["threshold_alert_triggered"]:
        raise AssertionError("Self-test normal threshold unexpectedly triggered alert")
    exceeded = evaluate_compute_cost_report(
        daily_threshold_usd=0.001,
        monthly_threshold_usd=0.01,
    )
    if not exceeded["threshold_alert_triggered"]:
        raise AssertionError("Self-test tight threshold failed to trigger alert")
    return {
        "self_test": "passed",
        "normal_daily_cost_usd": normal["latest_daily_cost_usd"],
        "exceeded_alert_triggered": exceeded["threshold_alert_triggered"],
        "rate_profiles": len(DEFAULT_GPU_RATE_CARD),
    }


def _write_github_output(path: str, report: dict[str, object]) -> None:
    lines = [
        f"status={report['status']}",
        f"threshold_alert_triggered={str(report['threshold_alert_triggered']).lower()}",
        f"latest_daily_cost_usd={report['latest_daily_cost_usd']}",
        f"latest_monthly_cost_usd={report['latest_monthly_cost_usd']}",
        f"total_requests={report['total_requests']}",
        f"avg_latency_ms={report['avg_latency_ms']}",
    ]
    Path(path).write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="AI compute/GPU cost & latency telemetry evaluator (#2658)."
    )
    parser.add_argument("--dry-run", action="store_true", help="Do not send external webhook alerts.")
    parser.add_argument("--live", action="store_true", help="Send webhook alert if threshold exceeded.")
    parser.add_argument("--self-test", action="store_true", help="Run offline deterministic self-test.")
    parser.add_argument("--daily-threshold-usd", type=float, default=DEFAULT_DAILY_THRESHOLD_USD)
    parser.add_argument("--monthly-threshold-usd", type=float, default=DEFAULT_MONTHLY_THRESHOLD_USD)
    parser.add_argument("--webhook-url", default="", help="Optional HTTPS webhook for threshold alert.")
    parser.add_argument("--json-out", default="")
    parser.add_argument("--markdown-out", default="")
    parser.add_argument("--github-output", default="")
    args = parser.parse_args(argv)

    if args.self_test:
        print(json.dumps(run_self_test(), ensure_ascii=False))
        return 0

    mode = "dry-run" if args.dry_run or not args.live else "live"
    report = evaluate_compute_cost_report(
        daily_threshold_usd=args.daily_threshold_usd,
        monthly_threshold_usd=args.monthly_threshold_usd,
    )
    markdown = render_markdown_report(report, mode=mode)

    if mode == "live" and report["threshold_alert_triggered"] and args.webhook_url.strip():
        post_json_pinned_https(args.webhook_url.strip(), report)

    if args.json_out:
        Path(args.json_out).write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if args.markdown_out:
        Path(args.markdown_out).write_text(markdown, encoding="utf-8")
    if args.github_output:
        _write_github_output(args.github_output, report)

    print(markdown.strip())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
