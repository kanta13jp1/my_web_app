#!/usr/bin/env python3
"""Bounded load harness for MUSUBI read paths.

The harness is dry-run by default. Network traffic requires --execute, which
prevents an accidental production load test during routine validation.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import math
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from typing import Iterable


@dataclass(frozen=True)
class RequestSpec:
    name: str
    method: str
    path: str
    body: dict[str, object] | None = None


@dataclass(frozen=True)
class RequestResult:
    name: str
    status: int
    latency_ms: float
    ok: bool
    error: str = ""


def build_plan(scenario: str, requests: int, query: str) -> list[RequestSpec]:
    if requests < 1 or requests > 10_000:
        raise ValueError("requests must be between 1 and 10000")
    timeline = RequestSpec(
        name="timeline",
        method="GET",
        path=(
            "/rest/v1/musubi_posts?"
            "select=id,author_id,created_at&moderation_status=eq.published&"
            "audience=eq.public&order=created_at.desc&limit=50"
        ),
    )
    search = RequestSpec(
        name="search",
        method="POST",
        path="/rest/v1/rpc/search_musubi",
        body={"search_query": query, "result_limit": 30},
    )
    messages = RequestSpec(
        name="messages",
        method="GET",
        path=(
            "/rest/v1/musubi_messages?"
            "select=id,thread_id,created_at&order=created_at.desc&limit=20"
        ),
    )
    templates = {
        "timeline": [timeline],
        "search": [search],
        "messages": [messages],
        "mixed": [timeline, search, timeline, messages, search],
    }
    selected = templates[scenario]
    return [selected[index % len(selected)] for index in range(requests)]


def percentile(values: Iterable[float], quantile: float) -> float:
    ordered = sorted(values)
    if not ordered:
        return 0.0
    index = max(0, math.ceil(len(ordered) * quantile) - 1)
    return ordered[index]


def execute_request(
    base_url: str,
    spec: RequestSpec,
    *,
    api_key: str,
    auth_token: str,
    timeout_seconds: float,
) -> RequestResult:
    started = time.perf_counter()
    data = None if spec.body is None else json.dumps(spec.body).encode("utf-8")
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "apikey": api_key,
        "Authorization": f"Bearer {auth_token or api_key}",
        "User-Agent": "musubi-bounded-load-test/1.0",
    }
    request = urllib.request.Request(
        urllib.parse.urljoin(base_url.rstrip("/") + "/", spec.path.lstrip("/")),
        data=data,
        headers=headers,
        method=spec.method,
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout_seconds) as response:
            response.read()
            status = response.status
            ok = 200 <= status < 400
            error = ""
    except urllib.error.HTTPError as exc:
        status = exc.code
        ok = False
        error = exc.read(300).decode("utf-8", errors="replace")
    except Exception as exc:  # Network failures belong in the load report.
        status = 0
        ok = False
        error = str(exc)
    latency_ms = (time.perf_counter() - started) * 1000
    return RequestResult(spec.name, status, round(latency_ms, 2), ok, error)


def run_load(
    base_url: str,
    plan: list[RequestSpec],
    *,
    concurrency: int,
    api_key: str,
    auth_token: str,
    timeout_seconds: float,
) -> list[RequestResult]:
    if concurrency < 1 or concurrency > 100:
        raise ValueError("concurrency must be between 1 and 100")
    with concurrent.futures.ThreadPoolExecutor(max_workers=concurrency) as pool:
        futures = [
            pool.submit(
                execute_request,
                base_url,
                spec,
                api_key=api_key,
                auth_token=auth_token,
                timeout_seconds=timeout_seconds,
            )
            for spec in plan
        ]
        return [future.result() for future in futures]


def summarize(results: list[RequestResult]) -> dict[str, object]:
    latencies = [result.latency_ms for result in results]
    failures = [result for result in results if not result.ok]
    by_scenario: dict[str, dict[str, object]] = {}
    for name in sorted({result.name for result in results}):
        group = [result for result in results if result.name == name]
        group_latencies = [result.latency_ms for result in group]
        by_scenario[name] = {
            "requests": len(group),
            "failures": sum(not result.ok for result in group),
            "p50_ms": round(percentile(group_latencies, 0.50), 2),
            "p95_ms": round(percentile(group_latencies, 0.95), 2),
        }
    return {
        "requests": len(results),
        "failures": len(failures),
        "error_rate": round(len(failures) / max(1, len(results)), 4),
        "p50_ms": round(percentile(latencies, 0.50), 2),
        "p95_ms": round(percentile(latencies, 0.95), 2),
        "max_ms": round(max(latencies, default=0.0), 2),
        "scenarios": by_scenario,
        "sample_errors": [asdict(result) for result in failures[:5]],
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scenario",
        choices=("timeline", "search", "messages", "mixed"),
        default="mixed",
    )
    parser.add_argument("--requests", type=int, default=50)
    parser.add_argument("--concurrency", type=int, default=5)
    parser.add_argument("--query", default="地域")
    parser.add_argument("--base-url", default=os.getenv("SUPABASE_URL", ""))
    parser.add_argument("--api-key", default=os.getenv("SUPABASE_ANON_KEY", ""))
    parser.add_argument("--auth-token", default=os.getenv("MUSUBI_TEST_JWT", ""))
    parser.add_argument("--timeout-seconds", type=float, default=10.0)
    parser.add_argument("--p95-budget-ms", type=float, default=1500.0)
    parser.add_argument("--max-error-rate", type=float, default=0.02)
    parser.add_argument(
        "--execute",
        action="store_true",
        help="Send network traffic. Without this flag only the plan is printed.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    plan = build_plan(args.scenario, args.requests, args.query)
    if not args.execute:
        print(
            json.dumps(
                {
                    "mode": "dry-run",
                    "requests": len(plan),
                    "concurrency": args.concurrency,
                    "scenario_counts": {
                        name: sum(spec.name == name for spec in plan)
                        for name in sorted({spec.name for spec in plan})
                    },
                    "next": "Add --execute with an approved staging URL and test JWT.",
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        return 0
    if not args.base_url or not args.api_key:
        raise SystemExit("--base-url and --api-key are required with --execute")

    started = time.perf_counter()
    results = run_load(
        args.base_url,
        plan,
        concurrency=args.concurrency,
        api_key=args.api_key,
        auth_token=args.auth_token,
        timeout_seconds=args.timeout_seconds,
    )
    report = summarize(results)
    report["duration_seconds"] = round(time.perf_counter() - started, 2)
    report["concurrency"] = args.concurrency
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return int(
        report["p95_ms"] > args.p95_budget_ms
        or report["error_rate"] > args.max_error_rate
    )


if __name__ == "__main__":
    raise SystemExit(main())
