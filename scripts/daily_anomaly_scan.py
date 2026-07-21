#!/usr/bin/env python3
"""Run the daily asset anomaly scan for eligible Supabase Auth users."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
ISSUE = "#2478"
UUID_PATTERN = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
    re.IGNORECASE,
)
TARGET_MONTH_PATTERN = re.compile(r"^\d{4}-(0[1-9]|1[0-2])(?:-01)?$")


@dataclass(frozen=True)
class ScanConfig:
    supabase_url: str
    service_role_key: str
    cron_enabled: bool
    manual_run: bool
    confirm_all_users: bool
    user_id: str
    target_month: str
    max_attempts: int
    workers: int
    timeout: int
    slack_webhook_url: str
    discord_webhook_url: str


class DailyAnomalyScanError(RuntimeError):
    pass


def parse_bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    if text in {"1", "true", "yes", "y", "on"}:
        return True
    if text in {"0", "false", "no", "n", "off", ""}:
        return False
    return default


def normalize_base_url(value: str) -> str:
    return (value or DEFAULT_SUPABASE_URL).rstrip("/")


def parse_timestamp(value: Any) -> datetime | None:
    if not isinstance(value, str) or not value.strip():
        return None
    text = value.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def is_eligible_auth_user(user: dict[str, Any], now: datetime) -> bool:
    user_id = str(user.get("id", "")).strip()
    if not UUID_PATTERN.fullmatch(user_id):
        return False
    if user.get("is_anonymous") is True or user.get("deleted_at"):
        return False
    banned_until = parse_timestamp(user.get("banned_until"))
    return banned_until is None or banned_until <= now.astimezone(timezone.utc)


def user_reference(user_id: str) -> str:
    return hashlib.sha256(user_id.encode("utf-8")).hexdigest()[:12]


def get_json(
    url: str,
    headers: dict[str, str],
    timeout: int,
) -> tuple[int, dict[str, Any]]:
    request = urllib.request.Request(url, headers=headers, method="GET")
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8", errors="replace")
        parsed = json.loads(body) if body.strip() else {}
        if not isinstance(parsed, dict):
            raise DailyAnomalyScanError("response must be a JSON object")
        return int(response.status), parsed


def post_json(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
) -> tuple[int, dict[str, Any]]:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        body = response.read().decode("utf-8", errors="replace")
        parsed = json.loads(body) if body.strip() else {}
        if not isinstance(parsed, dict):
            raise DailyAnomalyScanError("response must be a JSON object")
        return int(response.status), parsed


def post_webhook(url: str, payload: dict[str, Any], timeout: int) -> None:
    request = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        response.read()


def auth_headers(config: ScanConfig) -> dict[str, str]:
    return {
        "apikey": config.service_role_key,
        "Authorization": f"Bearer {config.service_role_key}",
        "Content-Type": "application/json",
        "User-Agent": "my-web-app-daily-anomaly-scan/1.0",
    }


def list_auth_users(
    config: ScanConfig,
    *,
    requester: Callable[
        [str, dict[str, str], int], tuple[int, dict[str, Any]]
    ] = get_json,
) -> list[dict[str, Any]]:
    users: list[dict[str, Any]] = []
    per_page = 1000
    base_url = normalize_base_url(config.supabase_url)
    for page in range(1, 101):
        query = urllib.parse.urlencode({"page": page, "per_page": per_page})
        _, response = requester(
            f"{base_url}/auth/v1/admin/users?{query}",
            auth_headers(config),
            config.timeout,
        )
        raw_users = response.get("users")
        if not isinstance(raw_users, list):
            raise DailyAnomalyScanError("Auth Admin response is missing users")
        batch = [item for item in raw_users if isinstance(item, dict)]
        users.extend(batch)
        if len(batch) < per_page:
            return users
    raise DailyAnomalyScanError("Auth Admin pagination exceeded 100 pages")


def build_scan_payload(config: ScanConfig, user_id: str) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "action": "asset.anomaly.detect.scheduled",
        "user_id": user_id,
    }
    if config.target_month:
        payload["target_month"] = config.target_month
    return payload


def should_retry_http(status: int) -> bool:
    return status == 429 or status >= 500


def scan_user(
    config: ScanConfig,
    user_id: str,
    *,
    requester: Callable[
        [str, dict[str, Any], dict[str, str], int], tuple[int, dict[str, Any]]
    ] = post_json,
    sleeper: Callable[[float], None] = time.sleep,
) -> dict[str, Any]:
    endpoint = f"{normalize_base_url(config.supabase_url)}/functions/v1/ai-hub"
    payload = build_scan_payload(config, user_id)
    last_reason = "unknown"
    last_error = ""

    for attempt in range(1, config.max_attempts + 1):
        retryable = True
        try:
            http_status, response = requester(
                endpoint,
                payload,
                auth_headers(config),
                config.timeout,
            )
            if response.get("success") is True and response.get("status") == "ok":
                return {
                    "status": "pass",
                    "user_ref": user_reference(user_id),
                    "attempts": attempt,
                    "anomalies_detected": int(response.get("anomalies_detected", 0)),
                    "warnings": len(response.get("warnings", [])),
                }
            last_reason = f"edge_function_http_{http_status}"
            last_error = str(response.get("error", "edge function returned failure"))[:500]
            retryable = should_retry_http(http_status) or http_status == 200
        except urllib.error.HTTPError as exc:
            last_reason = f"http_{exc.code}"
            last_error = exc.read().decode("utf-8", errors="replace")[:500]
            retryable = should_retry_http(exc.code)
        except Exception as exc:
            last_reason = "request_error"
            last_error = str(exc)[:500]

        if attempt < config.max_attempts and retryable:
            sleeper(float(2 ** (attempt - 1)))
            continue
        break

    return {
        "status": "fail",
        "user_ref": user_reference(user_id),
        "attempts": attempt,
        "reason": last_reason,
        "error": last_error,
    }


def build_report(
    config: ScanConfig,
    *,
    now: datetime | None = None,
    user_lister: Callable[[ScanConfig], list[dict[str, Any]]] = list_auth_users,
    scanner: Callable[[ScanConfig, str], dict[str, Any]] = scan_user,
) -> dict[str, Any]:
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    base = {
        "issue": ISSUE,
        "target_month": config.target_month or "previous_complete_month_jst",
    }

    if not config.manual_run and not config.cron_enabled:
        return {**base, "status": "skipped", "reason": "feature_flag_off"}
    if config.manual_run and not config.user_id and not config.confirm_all_users:
        return {
            **base,
            "status": "skipped",
            "reason": "manual_all_users_not_confirmed",
        }
    if not config.service_role_key:
        return {
            **base,
            "status": "fail",
            "reason": "missing_SUPABASE_SERVICE_ROLE_KEY",
        }
    if config.target_month and not TARGET_MONTH_PATTERN.fullmatch(config.target_month):
        return {**base, "status": "fail", "reason": "invalid_target_month"}

    if config.user_id:
        if not UUID_PATTERN.fullmatch(config.user_id):
            return {**base, "status": "fail", "reason": "invalid_user_id"}
        user_ids = [config.user_id]
        discovered_count = 1
    else:
        try:
            users = user_lister(config)
        except Exception as exc:
            return {
                **base,
                "status": "fail",
                "reason": "auth_user_list_failed",
                "error": str(exc)[:500],
            }
        discovered_count = len(users)
        user_ids = sorted(
            str(user["id"]).strip()
            for user in users
            if is_eligible_auth_user(user, current)
        )

    results: list[dict[str, Any]] = []
    workers = min(max(config.workers, 1), max(len(user_ids), 1))
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(scanner, config, user_id): user_id for user_id in user_ids}
        for future in as_completed(futures):
            user_id = futures[future]
            try:
                results.append(future.result())
            except Exception as exc:
                results.append(
                    {
                        "status": "fail",
                        "user_ref": user_reference(user_id),
                        "attempts": 1,
                        "reason": "worker_error",
                        "error": str(exc)[:500],
                    }
                )

    results.sort(key=lambda item: str(item.get("user_ref", "")))
    failed = [item for item in results if item.get("status") != "pass"]
    return {
        **base,
        "status": "fail" if failed else "pass",
        "reason": "user_scan_failed" if failed else "all_eligible_users_scanned",
        "users_discovered": discovered_count,
        "users_eligible": len(user_ids),
        "users_succeeded": len(results) - len(failed),
        "users_failed": len(failed),
        "anomalies_detected": sum(
            int(item.get("anomalies_detected", 0)) for item in results
        ),
        "results": results,
    }


def build_failure_text(report: dict[str, Any]) -> str:
    return (
        f"Daily anomaly scan failed ({ISSUE})\n"
        f"- reason: {report.get('reason', 'unknown')}\n"
        f"- eligible: {report.get('users_eligible', 0)}\n"
        f"- failed: {report.get('users_failed', 0)}\n"
        f"- run: {os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/"
        f"{os.environ.get('GITHUB_REPOSITORY', 'unknown')}/actions/runs/"
        f"{os.environ.get('GITHUB_RUN_ID', 'unknown')}"
    )


def notify_failure(
    config: ScanConfig,
    report: dict[str, Any],
    *,
    poster: Callable[[str, dict[str, Any], int], None] = post_webhook,
) -> list[str]:
    delivered: list[str] = []
    text = build_failure_text(report)
    for name, url, payload in (
        ("slack", config.slack_webhook_url, {"text": text}),
        ("discord", config.discord_webhook_url, {"content": text}),
    ):
        if not url:
            continue
        try:
            poster(url, payload, min(config.timeout, 10))
            delivered.append(name)
        except Exception as exc:  # pragma: no cover - transport failures vary.
            delivered.append(f"{name}_error:{exc}")
    return delivered


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Daily Anomaly Scan",
        "",
        f"- Issue: `{report.get('issue', ISSUE)}`",
        f"- Status: `{report.get('status', 'unknown')}`",
        f"- Reason: `{report.get('reason', 'unknown')}`",
        f"- Target month: `{report.get('target_month', 'unknown')}`",
        f"- Users discovered: `{report.get('users_discovered', 0)}`",
        f"- Users eligible: `{report.get('users_eligible', 0)}`",
        f"- Users succeeded: `{report.get('users_succeeded', 0)}`",
        f"- Users failed: `{report.get('users_failed', 0)}`",
        f"- Anomalies detected: `{report.get('anomalies_detected', 0)}`",
    ]
    return "\n".join(lines) + "\n"


def write_outputs(report: dict[str, Any], report_path: str, summary_path: str) -> None:
    if report_path:
        path = Path(report_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    if summary_path:
        path = Path(summary_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(render_markdown(report), encoding="utf-8", newline="\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--service-role-key", default=os.environ.get("SUPABASE_SERVICE_ROLE_KEY", ""))
    parser.add_argument("--cron-enabled", default=os.environ.get("DAILY_ANOMALY_SCAN_ENABLED", "false"))
    parser.add_argument("--manual-run", default=os.environ.get("DAILY_ANOMALY_SCAN_MANUAL_RUN", "false"))
    parser.add_argument("--confirm-all-users", default=os.environ.get("DAILY_ANOMALY_SCAN_CONFIRM_ALL_USERS", "false"))
    parser.add_argument("--user-id", default=os.environ.get("DAILY_ANOMALY_SCAN_USER_ID", ""))
    parser.add_argument("--target-month", default=os.environ.get("DAILY_ANOMALY_SCAN_TARGET_MONTH", ""))
    parser.add_argument("--max-attempts", type=int, default=3)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--slack-webhook-url", default=os.environ.get("SLACK_WEBHOOK_URL", ""))
    parser.add_argument("--discord-webhook-url", default=os.environ.get("DISCORD_WEBHOOK_URL", ""))
    parser.add_argument("--report", default="")
    parser.add_argument("--summary-md", default="")
    return parser


def config_from_args(args: argparse.Namespace) -> ScanConfig:
    return ScanConfig(
        supabase_url=args.supabase_url.strip(),
        service_role_key=args.service_role_key.strip(),
        cron_enabled=parse_bool(args.cron_enabled),
        manual_run=parse_bool(args.manual_run),
        confirm_all_users=parse_bool(args.confirm_all_users),
        user_id=args.user_id.strip(),
        target_month=args.target_month.strip(),
        max_attempts=min(max(args.max_attempts, 1), 5),
        workers=min(max(args.workers, 1), 16),
        timeout=min(max(args.timeout, 1), 120),
        slack_webhook_url=args.slack_webhook_url.strip(),
        discord_webhook_url=args.discord_webhook_url.strip(),
    )


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    config = config_from_args(args)
    report = build_report(config)
    if report["status"] == "fail":
        report["notifications"] = notify_failure(config, report)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    write_outputs(report, args.report, args.summary_md)
    return 1 if report["status"] == "fail" else 0


if __name__ == "__main__":
    sys.exit(main())
