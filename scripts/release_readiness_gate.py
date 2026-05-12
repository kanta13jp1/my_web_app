#!/usr/bin/env python3
"""Runtime smoke checks for the alpha release readiness gate.

The workflow owns heavyweight static checks (Flutter analyze/build, Deno
lint/check, migration timestamp checks). This helper keeps the runtime side
dependency-free: production routes, Edge Function hub actions, Slack
notification readiness, and the optional WBS completion update.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_BASE_URL = "https://my-web-app-b67f4.web.app"
DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
DEFAULT_ROUTES = ("/", "/project-gantt", "/referral")
USER_AGENT = "release-readiness-gate/1.0"


@dataclass(frozen=True)
class CheckResult:
    name: str
    category: str
    status: str
    detail: str
    target: str = ""
    http_status: int | None = None

    @property
    def failed(self) -> bool:
        return self.status == "failure"


def append_summary(summary_path: str | None, title: str, lines: list[str]) -> None:
    if not summary_path:
        return
    path = Path(summary_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(f"\n## {title}\n\n")
        for line in lines:
            handle.write(f"{line}\n")


def normalize_base_url(url: str) -> str:
    cleaned = (url or DEFAULT_BASE_URL).strip()
    if not cleaned:
        cleaned = DEFAULT_BASE_URL
    return cleaned.rstrip("/")


def join_url(root: str, path: str) -> str:
    root = normalize_base_url(root)
    path = "/" + path.lstrip("/")
    return f"{root}{path}"


def decode_json(text: str) -> Any:
    if not text.strip():
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return None


def request_text(
    url: str,
    *,
    method: str = "GET",
    headers: dict[str, str] | None = None,
    payload: dict[str, Any] | None = None,
    timeout: int = 20,
) -> tuple[int, str]:
    request_headers = {
        "User-Agent": USER_AGENT,
        **(headers or {}),
    }
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        request_headers.setdefault("Content-Type", "application/json")
    request = urllib.request.Request(
        url,
        data=data,
        headers=request_headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read().decode("utf-8", errors="replace")
            return int(response.status), body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return int(exc.code), body


def service_headers(service_role_key: str) -> dict[str, str]:
    return {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
    }


def success_json(payload: Any) -> bool:
    if isinstance(payload, dict) and payload.get("success") is False:
        return False
    return isinstance(payload, dict)


def check_routes(base_url: str, routes: list[str], timeout: int) -> list[CheckResult]:
    results: list[CheckResult] = []
    for route in routes:
        url = join_url(base_url, route)
        try:
            status, text = request_text(url, timeout=timeout)
            ok = 200 <= status < 400 and bool(text.strip())
            results.append(
                CheckResult(
                    name=f"route {route}",
                    category="production_http",
                    status="success" if ok else "failure",
                    detail="HTTP route returned a non-empty response"
                    if ok
                    else "HTTP route did not return a healthy response",
                    target=url,
                    http_status=status,
                )
            )
        except Exception as exc:  # pragma: no cover - exercised by workflow
            results.append(
                CheckResult(
                    name=f"route {route}",
                    category="production_http",
                    status="failure",
                    detail=str(exc),
                    target=url,
                )
            )
    return results


def check_hub_action(
    supabase_url: str,
    service_role_key: str,
    function_name: str,
    action: str,
    *,
    timeout: int,
) -> CheckResult:
    if not service_role_key:
        return CheckResult(
            name=f"{function_name}:{action}",
            category="edge_hub",
            status="failure",
            detail="SUPABASE_SERVICE_ROLE_KEY is required for release readiness hub smoke",
        )

    target = join_url(supabase_url or DEFAULT_SUPABASE_URL, f"/functions/v1/{function_name}")
    try:
        status, text = request_text(
            target,
            method="POST",
            headers=service_headers(service_role_key),
            payload={"action": action},
            timeout=timeout,
        )
        payload = decode_json(text)
        ok = 200 <= status < 300 and success_json(payload)
        detail = "hub action returned success JSON" if ok else text[:500]
        return CheckResult(
            name=f"{function_name}:{action}",
            category="edge_hub",
            status="success" if ok else "failure",
            detail=detail,
            target=target,
            http_status=status,
        )
    except Exception as exc:  # pragma: no cover - exercised by workflow
        return CheckResult(
            name=f"{function_name}:{action}",
            category="edge_hub",
            status="failure",
            detail=str(exc),
            target=target,
        )


def check_slack(
    webhook_url: str,
    *,
    require_webhook: bool,
    send_probe: bool,
    timeout: int,
) -> CheckResult:
    if not webhook_url:
        return CheckResult(
            name="Slack webhook",
            category="notification",
            status="failure" if require_webhook else "skip",
            detail="SLACK_WEBHOOK_URL is not configured",
        )
    if not send_probe:
        return CheckResult(
            name="Slack webhook",
            category="notification",
            status="success",
            detail="SLACK_WEBHOOK_URL is configured; send probe disabled",
        )
    payload = {
        "text": "Release readiness smoke reached Slack notification path.",
    }
    try:
        status, text = request_text(
            webhook_url,
            method="POST",
            payload=payload,
            timeout=timeout,
        )
        ok = 200 <= status < 300
        return CheckResult(
            name="Slack webhook",
            category="notification",
            status="success" if ok else "failure",
            detail="Slack accepted the readiness probe" if ok else text[:500],
            http_status=status,
        )
    except Exception as exc:  # pragma: no cover - exercised by workflow
        return CheckResult(
            name="Slack webhook",
            category="notification",
            status="failure",
            detail=str(exc),
        )


def find_wbs_task_id(
    supabase_url: str,
    service_role_key: str,
    issue_number: int,
    timeout: int,
) -> tuple[str | None, str]:
    query = urllib.parse.urlencode(
        {
            "select": "id,title,status,progress,github_issue_number",
            "github_issue_number": f"eq.{issue_number}",
            "order": "updated_at.desc",
            "limit": "1",
        }
    )
    target = join_url(supabase_url or DEFAULT_SUPABASE_URL, f"/rest/v1/wbs_tasks?{query}")
    status, text = request_text(
        target,
        headers=service_headers(service_role_key),
        timeout=timeout,
    )
    if not (200 <= status < 300):
        return None, f"WBS lookup failed with HTTP {status}: {text[:300]}"
    payload = decode_json(text)
    if not isinstance(payload, list) or not payload:
        return None, f"No WBS task found for GitHub issue #{issue_number}"
    task = payload[0]
    task_id = str(task.get("id") or "")
    title = str(task.get("title") or "")
    if not task_id:
        return None, f"WBS task for issue #{issue_number} did not include id"
    return task_id, title


def update_wbs_success(
    supabase_url: str,
    service_role_key: str,
    issue_number: int,
    timeout: int,
) -> CheckResult:
    if not service_role_key:
        return CheckResult(
            name="WBS release gate update",
            category="wbs",
            status="skip",
            detail="SUPABASE_SERVICE_ROLE_KEY missing; WBS update skipped",
        )
    try:
        task_id, lookup_detail = find_wbs_task_id(
            supabase_url,
            service_role_key,
            issue_number,
            timeout,
        )
        if not task_id:
            return CheckResult(
                name="WBS release gate update",
                category="wbs",
                status="skip",
                detail=lookup_detail,
            )
        target = join_url(supabase_url or DEFAULT_SUPABASE_URL, "/functions/v1/tools-hub")
        status, text = request_text(
            target,
            method="POST",
            headers=service_headers(service_role_key),
            payload={
                "action": "wbs.update_progress",
                "id": task_id,
                "progress": 100,
                "status": "completed",
                "note": (
                    "Release Readiness Gate succeeded for alpha release "
                    f"issue #{issue_number}."
                ),
            },
            timeout=timeout,
        )
        payload = decode_json(text)
        ok = 200 <= status < 300 and success_json(payload)
        return CheckResult(
            name="WBS release gate update",
            category="wbs",
            status="success" if ok else "failure",
            detail=f"Updated WBS task {task_id} ({lookup_detail})"
            if ok
            else text[:500],
            target=target,
            http_status=status,
        )
    except Exception as exc:  # pragma: no cover - exercised by workflow
        return CheckResult(
            name="WBS release gate update",
            category="wbs",
            status="failure",
            detail=str(exc),
        )


def render_markdown(results: list[CheckResult]) -> list[str]:
    failed = sum(1 for result in results if result.status == "failure")
    skipped = sum(1 for result in results if result.status == "skip")
    lines = [
        f"- Checked at: `{datetime.now(timezone.utc).isoformat()}`",
        f"- Overall: `{'failure' if failed else 'success'}`",
        f"- Failed checks: `{failed}`",
        f"- Skipped checks: `{skipped}`",
        "",
        "| Category | Check | Status | HTTP | Target | Detail |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for result in results:
        detail = result.detail.replace("\n", " ")[:240]
        target = result.target or "-"
        http_status = str(result.http_status) if result.http_status is not None else "-"
        lines.append(
            f"| `{result.category}` | `{result.name}` | `{result.status}` | "
            f"`{http_status}` | {target} | {detail} |"
        )
    return lines


def write_json_report(path: str | None, results: list[CheckResult]) -> None:
    if not path:
        return
    output = Path(path)
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "success": not any(result.failed for result in results),
        "results": [asdict(result) for result in results],
    }
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run release readiness runtime smoke checks")
    parser.add_argument("--base-url", default=os.environ.get("BASE_URL", DEFAULT_BASE_URL))
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument(
        "--service-role-key",
        default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""),
    )
    parser.add_argument("--slack-webhook-url", default=os.environ.get("SLACK_WEBHOOK_URL", ""))
    parser.add_argument("--route", action="append", dest="routes")
    parser.add_argument("--timeout-sec", type=int, default=20)
    parser.add_argument("--summary")
    parser.add_argument("--output-json")
    parser.add_argument("--require-slack-webhook", action="store_true")
    parser.add_argument("--send-slack", action="store_true")
    parser.add_argument("--update-wbs", action="store_true")
    parser.add_argument("--issue-number", type=int, default=1556)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    routes = args.routes or list(DEFAULT_ROUTES)

    results: list[CheckResult] = []
    results.extend(check_routes(args.base_url, routes, args.timeout_sec))
    results.append(
        check_hub_action(
            args.supabase_url,
            args.service_role_key,
            "tools-hub",
            "wbs.project_overview",
            timeout=args.timeout_sec,
        )
    )
    results.append(
        check_hub_action(
            args.supabase_url,
            args.service_role_key,
            "schedule-hub",
            "health.check",
            timeout=args.timeout_sec,
        )
    )
    results.append(
        check_hub_action(
            args.supabase_url,
            args.service_role_key,
            "schedule-hub",
            "notion.preflight_wbs",
            timeout=args.timeout_sec,
        )
    )
    results.append(
        check_slack(
            args.slack_webhook_url,
            require_webhook=args.require_slack_webhook,
            send_probe=args.send_slack,
            timeout=args.timeout_sec,
        )
    )

    if args.update_wbs and not any(result.failed for result in results):
        results.append(
            update_wbs_success(
                args.supabase_url,
                args.service_role_key,
                args.issue_number,
                args.timeout_sec,
            )
        )

    lines = render_markdown(results)
    append_summary(args.summary, "Release readiness runtime smoke", lines)
    write_json_report(args.output_json, results)
    print("\n".join(lines))
    return 1 if any(result.failed for result in results) else 0


if __name__ == "__main__":
    raise SystemExit(main())
