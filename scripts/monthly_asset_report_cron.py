#!/usr/bin/env python3
"""Run the month-end asset report Edge Function from GitHub Actions.

The workflow is intentionally staged:
- scheduled runs are disabled until ASSET_MONTHLY_REPORT_CRON_ENABLED=true,
- user JWT auth must be supplied via ASSET_MONTHLY_REPORT_USER_JWT,
- AI summaries stay off unless explicitly enabled.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable
from zoneinfo import ZoneInfo


DEFAULT_SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
ISSUE = "#2462"
JST = ZoneInfo("Asia/Tokyo")
YEAR_MONTH_PATTERN = re.compile(r"^\d{4}-\d{2}$")


@dataclass(frozen=True)
class CronConfig:
    supabase_url: str
    anon_key: str
    user_jwt: str
    cron_enabled: bool
    manual_run: bool
    force: bool
    dry_run: bool
    enable_ai_summary: bool
    strict_secrets: bool
    year_month: str
    provider: str
    timeout: int
    slack_webhook_url: str
    discord_webhook_url: str


class MonthlyAssetReportCronError(RuntimeError):
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


def month_rollover_jst(now: datetime) -> bool:
    now_jst = now.astimezone(JST)
    return now_jst.day == 1


def previous_month_key(now: datetime) -> str:
    now_jst = now.astimezone(JST)
    year = now_jst.year
    month = now_jst.month - 1
    if month == 0:
        year -= 1
        month = 12
    return f"{year:04d}-{month:02d}"


def normalize_year_month(value: str, now: datetime) -> str:
    text = value.strip()
    if not text:
        return previous_month_key(now)
    if re.match(r"^\d{4}-\d{2}-\d{2}$", text):
        text = text[:7]
    if not YEAR_MONTH_PATTERN.match(text):
        raise MonthlyAssetReportCronError("year_month must be YYYY-MM or YYYY-MM-DD")
    month = int(text[5:7])
    if month < 1 or month > 12:
        raise MonthlyAssetReportCronError("year_month month is invalid")
    return text


def normalize_base_url(value: str) -> str:
    return (value or DEFAULT_SUPABASE_URL).rstrip("/")


def build_payload(config: CronConfig, target_month: str, run_id: str) -> dict[str, Any]:
    return {
        "action": "asset.monthly_report.generate",
        "year_month": target_month,
        "dry_run": config.dry_run,
        "enable_ai_summary": config.enable_ai_summary,
        "provider_preference": config.provider or "google",
        "routing_use_case": "asset_monthly_report_cron",
        "provider_choice_reason": "month-end scheduled asset report cron (#2462)",
        "trace_id": run_id,
    }


def request_json(
    url: str,
    payload: dict[str, Any],
    headers: dict[str, str],
    timeout: int,
) -> tuple[int, dict[str, Any]]:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    with urllib.request.urlopen(req, timeout=timeout) as response:
        body = response.read().decode("utf-8", errors="replace")
        parsed = json.loads(body) if body.strip() else {}
        if not isinstance(parsed, dict):
            raise MonthlyAssetReportCronError("Edge Function response must be a JSON object")
        return int(response.status), parsed


def post_json(url: str, payload: dict[str, Any], timeout: int) -> None:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as response:
        response.read()


def build_failure_text(report: dict[str, Any]) -> str:
    reason = report.get("reason") or report.get("error") or "unknown"
    target_month = report.get("target_month", "unknown")
    return (
        f"Monthly asset report cron failed ({ISSUE})\n"
        f"- target_month: {target_month}\n"
        f"- reason: {reason}"
    )


def notify_failure(
    config: CronConfig,
    report: dict[str, Any],
    *,
    poster: Callable[[str, dict[str, Any], int], None] = post_json,
) -> list[str]:
    delivered: list[str] = []
    text = build_failure_text(report)
    if config.slack_webhook_url:
        try:
            poster(config.slack_webhook_url, {"text": text}, min(config.timeout, 10))
            delivered.append("slack")
        except Exception as exc:  # pragma: no cover - transport failures vary.
            delivered.append(f"slack_error:{exc}")
    if config.discord_webhook_url:
        try:
            poster(config.discord_webhook_url, {"content": text}, min(config.timeout, 10))
            delivered.append("discord")
        except Exception as exc:  # pragma: no cover - transport failures vary.
            delivered.append(f"discord_error:{exc}")
    return delivered


def build_report(
    config: CronConfig,
    *,
    now: datetime | None = None,
    requester: Callable[[str, dict[str, Any], dict[str, str], int], tuple[int, dict[str, Any]]] = request_json,
) -> dict[str, Any]:
    current = now or datetime.now(timezone.utc)
    target_month = normalize_year_month(config.year_month, current)
    run_id = f"asset-monthly-report-{target_month}-{int(current.timestamp())}"

    if not config.manual_run and not config.cron_enabled:
        return {
            "status": "skipped",
            "reason": "feature_flag_off",
            "issue": ISSUE,
            "target_month": target_month,
            "dry_run": config.dry_run,
        }

    if (
        not config.manual_run and not config.force and not config.year_month and
        not month_rollover_jst(current)
    ):
        return {
            "status": "skipped",
            "reason": "not_month_rollover_jst",
            "issue": ISSUE,
            "target_month": target_month,
            "dry_run": config.dry_run,
        }

    if not config.user_jwt:
        status = "fail" if (
            config.strict_secrets or (config.cron_enabled and not config.manual_run)
        ) else "skipped"
        return {
            "status": status,
            "reason": "missing_ASSET_MONTHLY_REPORT_USER_JWT",
            "issue": ISSUE,
            "target_month": target_month,
            "dry_run": config.dry_run,
        }

    endpoint = f"{normalize_base_url(config.supabase_url)}/functions/v1/ai-hub"
    payload = build_payload(config, target_month, run_id)
    api_key = config.anon_key or config.user_jwt
    headers = {
        "apikey": api_key,
        "Authorization": f"Bearer {config.user_jwt}",
        "Content-Type": "application/json",
        "User-Agent": "my-web-app-monthly-asset-report-cron/1.0",
    }

    try:
        http_status, response = requester(endpoint, payload, headers, config.timeout)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return {
            "status": "fail",
            "reason": f"http_{exc.code}",
            "error": body[:1000],
            "issue": ISSUE,
            "target_month": target_month,
            "dry_run": config.dry_run,
            "payload": safe_payload(payload),
        }
    except Exception as exc:
        return {
            "status": "fail",
            "reason": "request_error",
            "error": str(exc),
            "issue": ISSUE,
            "target_month": target_month,
            "dry_run": config.dry_run,
            "payload": safe_payload(payload),
        }

    success = response.get("success") is True
    return {
        "status": "pass" if success else "fail",
        "reason": "edge_function_success" if success else "edge_function_error",
        "issue": ISSUE,
        "target_month": target_month,
        "dry_run": config.dry_run,
        "http_status": http_status,
        "payload": safe_payload(payload),
        "response": response,
    }


def safe_payload(payload: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in payload.items() if key not in {"snapshot"}}


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Monthly Asset Report Cron",
        "",
        f"- Issue: `{report.get('issue', ISSUE)}`",
        f"- Status: `{report.get('status', 'unknown')}`",
        f"- Reason: `{report.get('reason', 'unknown')}`",
        f"- Target month: `{report.get('target_month', 'unknown')}`",
        f"- Dry run: `{str(report.get('dry_run', False)).lower()}`",
    ]
    response = report.get("response")
    if isinstance(response, dict):
        lines.extend(
            [
                f"- EF status: `{response.get('status', 'unknown')}`",
                f"- AI enabled: `{str(response.get('ai_enabled', False)).lower()}`",
                f"- AI model: `{response.get('ai_model', 'n/a')}`",
            ]
        )
    return "\n".join(lines) + "\n"


def write_outputs(report: dict[str, Any], report_path: str, summary_path: str) -> None:
    if report_path:
        path = Path(report_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if summary_path:
        path = Path(summary_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(render_markdown(report), encoding="utf-8", newline="\n")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--supabase-url", default=os.environ.get("SUPABASE_URL", DEFAULT_SUPABASE_URL))
    parser.add_argument("--anon-key", default=os.environ.get("SUPABASE_ANON_KEY", ""))
    parser.add_argument("--user-jwt", default=os.environ.get("ASSET_MONTHLY_REPORT_USER_JWT", ""))
    parser.add_argument("--cron-enabled", default=os.environ.get("ASSET_MONTHLY_REPORT_CRON_ENABLED", "false"))
    parser.add_argument("--manual-run", default=os.environ.get("ASSET_MONTHLY_REPORT_MANUAL_RUN", "false"))
    parser.add_argument("--force", default=os.environ.get("ASSET_MONTHLY_REPORT_FORCE", "false"))
    parser.add_argument("--dry-run", default=os.environ.get("ASSET_MONTHLY_REPORT_DRY_RUN", "false"))
    parser.add_argument("--enable-ai-summary", default=os.environ.get("ASSET_MONTHLY_REPORT_AI_ENABLED", "false"))
    parser.add_argument("--strict-secrets", default=os.environ.get("ASSET_MONTHLY_REPORT_STRICT_SECRETS", "false"))
    parser.add_argument("--year-month", default=os.environ.get("ASSET_MONTHLY_REPORT_YEAR_MONTH", ""))
    parser.add_argument("--provider", default=os.environ.get("ASSET_MONTHLY_REPORT_PROVIDER", "google"))
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--slack-webhook-url", default=os.environ.get("SLACK_WEBHOOK_URL", ""))
    parser.add_argument("--discord-webhook-url", default=os.environ.get("DISCORD_WEBHOOK_URL", ""))
    parser.add_argument("--report", default="")
    parser.add_argument("--summary-md", default="")
    return parser


def config_from_args(args: argparse.Namespace) -> CronConfig:
    return CronConfig(
        supabase_url=args.supabase_url,
        anon_key=args.anon_key.strip(),
        user_jwt=args.user_jwt.strip(),
        cron_enabled=parse_bool(args.cron_enabled),
        manual_run=parse_bool(args.manual_run),
        force=parse_bool(args.force),
        dry_run=parse_bool(args.dry_run),
        enable_ai_summary=parse_bool(args.enable_ai_summary),
        strict_secrets=parse_bool(args.strict_secrets),
        year_month=args.year_month.strip(),
        provider=args.provider.strip() or "google",
        timeout=args.timeout,
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
