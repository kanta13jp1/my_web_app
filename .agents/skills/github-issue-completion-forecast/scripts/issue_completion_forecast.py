#!/usr/bin/env python3
"""Report the current GitHub Issue backlog and a completion forecast.

The command is intentionally read-only. It uses GitHub CLI authentication and
the Search Issues API to obtain aggregate counts before calculating a forecast.
"""

from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Sequence


JST = timezone(timedelta(hours=9), name="JST")
DEFAULT_MINIMUM_SAMPLE = 3


class ForecastError(RuntimeError):
    """Raised when fresh GitHub data cannot be obtained or validated."""


@dataclass(frozen=True)
class Forecast:
    repository: str
    generated_at: str
    completed_issue: int | None
    completed_issue_state: str | None
    open_issues: int
    closed_last_7_days: int
    closed_last_30_days: int
    average_per_day_7_days: float
    average_per_day_30_days: float
    estimated_days_remaining: float | None
    estimated_completion_at: str | None
    confidence: str
    minimum_sample: int


def _run_gh(arguments: Sequence[str]) -> str:
    if shutil.which("gh") is None:
        raise ForecastError("GitHub CLI (gh) was not found on PATH")

    command = ["gh", *arguments]
    result = subprocess.run(
        command,
        capture_output=True,
        check=False,
        encoding="utf-8",
        errors="replace",
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
        raise ForecastError(f"gh command failed: {detail}")
    return result.stdout.strip()


def _load_json(arguments: Sequence[str]) -> dict[str, Any]:
    raw = _run_gh(arguments)
    try:
        payload = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ForecastError("GitHub CLI returned invalid JSON") from exc
    if not isinstance(payload, dict):
        raise ForecastError("GitHub CLI returned an unexpected JSON value")
    return payload


def resolve_repository(explicit_repository: str | None) -> str:
    if explicit_repository:
        parts = explicit_repository.split("/")
        if len(parts) != 2 or not all(parts):
            raise ForecastError("--repo must use the owner/name format")
        return explicit_repository

    repository = _run_gh(
        ["repo", "view", "--json", "nameWithOwner", "--jq", ".nameWithOwner"]
    )
    if repository.count("/") != 1:
        raise ForecastError("Could not resolve the current GitHub repository")
    return repository


def search_count(repository: str, qualifiers: str) -> int:
    query = f"repo:{repository} is:issue {qualifiers}"
    payload = _load_json(
        [
            "api",
            "--method",
            "GET",
            "search/issues",
            "-f",
            f"q={query}",
            "-f",
            "per_page=1",
        ]
    )
    total_count = payload.get("total_count")
    if not isinstance(total_count, int) or total_count < 0:
        raise ForecastError("GitHub Search returned an invalid total_count")
    return total_count


def issue_state(repository: str, issue_number: int) -> str:
    payload = _load_json(["api", f"repos/{repository}/issues/{issue_number}"])
    if "pull_request" in payload:
        raise ForecastError(f"#{issue_number} is a pull request, not an Issue")
    state = payload.get("state")
    if state not in {"open", "closed"}:
        raise ForecastError(f"#{issue_number} returned an invalid Issue state")
    return state.upper()


def calculate_forecast(
    *,
    repository: str,
    now: datetime,
    open_issues: int,
    closed_last_7_days: int,
    closed_last_30_days: int,
    minimum_sample: int = DEFAULT_MINIMUM_SAMPLE,
    completed_issue: int | None = None,
    completed_issue_state: str | None = None,
) -> Forecast:
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    if min(open_issues, closed_last_7_days, closed_last_30_days) < 0:
        raise ValueError("Issue counts cannot be negative")
    if minimum_sample < 1:
        raise ValueError("minimum_sample must be at least 1")

    now_jst = now.astimezone(JST)
    rate_7_days = closed_last_7_days / 7
    rate_30_days = closed_last_30_days / 30
    estimated_days: float | None = None
    estimated_at: datetime | None = None

    if open_issues == 0:
        estimated_days = 0.0
        estimated_at = now_jst
        confidence = "not_applicable"
    elif closed_last_30_days < minimum_sample:
        confidence = "insufficient_data"
    else:
        estimated_days = open_issues / rate_30_days
        estimated_at = now_jst + timedelta(days=estimated_days)
        if closed_last_30_days < 10:
            confidence = "low"
        elif closed_last_30_days < 30:
            confidence = "medium_low"
        else:
            confidence = "medium"

    return Forecast(
        repository=repository,
        generated_at=now_jst.isoformat(timespec="seconds"),
        completed_issue=completed_issue,
        completed_issue_state=completed_issue_state,
        open_issues=open_issues,
        closed_last_7_days=closed_last_7_days,
        closed_last_30_days=closed_last_30_days,
        average_per_day_7_days=rate_7_days,
        average_per_day_30_days=rate_30_days,
        estimated_days_remaining=estimated_days,
        estimated_completion_at=(
            estimated_at.isoformat(timespec="seconds") if estimated_at else None
        ),
        confidence=confidence,
        minimum_sample=minimum_sample,
    )


def collect_forecast(
    *,
    repository: str,
    now: datetime,
    minimum_sample: int,
    completed_issue: int | None,
) -> Forecast:
    today = now.astimezone(JST).date()
    seven_day_start = today - timedelta(days=6)
    thirty_day_start = today - timedelta(days=29)
    completed_state = (
        issue_state(repository, completed_issue) if completed_issue is not None else None
    )
    return calculate_forecast(
        repository=repository,
        now=now,
        open_issues=search_count(repository, "is:open"),
        closed_last_7_days=search_count(
            repository, f"is:closed closed:>={seven_day_start.isoformat()}"
        ),
        closed_last_30_days=search_count(
            repository, f"is:closed closed:>={thirty_day_start.isoformat()}"
        ),
        minimum_sample=minimum_sample,
        completed_issue=completed_issue,
        completed_issue_state=completed_state,
    )


def format_markdown(forecast: Forecast) -> str:
    generated_at = datetime.fromisoformat(forecast.generated_at)
    lines = ["### Issue backlog forecast"]
    if forecast.completed_issue is not None:
        state = forecast.completed_issue_state or "UNKNOWN"
        inclusion = "（現在の件数に含む）" if state == "OPEN" else ""
        lines.append(
            f"- 対応Issue: #{forecast.completed_issue} {state}{inclusion}"
        )
    lines.extend(
        [
            f"- 現在のオープンIssue: {forecast.open_issues}件",
            (
                "- 直近7日: "
                f"{forecast.closed_last_7_days}件完了 "
                f"（{forecast.average_per_day_7_days:.2f}件/日）"
            ),
            (
                "- 直近30日: "
                f"{forecast.closed_last_30_days}件完了 "
                f"（{forecast.average_per_day_30_days:.2f}件/日）"
            ),
        ]
    )

    if forecast.estimated_completion_at is None:
        lines.append(
            "- 全件対応予定: 算出保留 "
            f"（直近30日の完了が{forecast.minimum_sample}件未満）"
        )
    else:
        estimated_at = datetime.fromisoformat(forecast.estimated_completion_at)
        days = math.ceil(forecast.estimated_days_remaining or 0)
        lines.append(
            "- 全件対応予定: "
            f"{estimated_at.strftime('%Y-%m-%d %H:%M JST')} "
            f"（約{days}日、信頼度: {forecast.confidence}）"
        )

    lines.extend(
        [
            "- 前提: 新規Issue 0件、直近30日の完了速度を維持",
            f"- 算出時刻: {generated_at.strftime('%Y-%m-%d %H:%M:%S JST')}",
        ]
    )
    return "\n".join(lines)


def parse_now(value: str | None) -> datetime:
    if value is None:
        return datetime.now(timezone.utc)
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("--now must be an ISO 8601 timestamp") from exc
    if parsed.tzinfo is None:
        raise argparse.ArgumentTypeError("--now must include a UTC offset")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Report the current GitHub Issue backlog and completion forecast."
    )
    parser.add_argument("--repo", help="GitHub repository in owner/name format")
    parser.add_argument("--completed-issue", type=int, metavar="NUMBER")
    parser.add_argument(
        "--minimum-sample",
        type=int,
        default=DEFAULT_MINIMUM_SAMPLE,
        help="minimum 30-day closed count required for a forecast (default: 3)",
    )
    parser.add_argument("--format", choices=("markdown", "json"), default="markdown")
    parser.add_argument("--now", help=argparse.SUPPRESS)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.completed_issue is not None and args.completed_issue < 1:
        parser.error("--completed-issue must be at least 1")
    if args.minimum_sample < 1:
        parser.error("--minimum-sample must be at least 1")

    try:
        now = parse_now(args.now)
        repository = resolve_repository(args.repo)
        forecast = collect_forecast(
            repository=repository,
            now=now,
            minimum_sample=args.minimum_sample,
            completed_issue=args.completed_issue,
        )
    except (ForecastError, argparse.ArgumentTypeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    if args.format == "json":
        print(json.dumps(asdict(forecast), ensure_ascii=False, indent=2))
    else:
        print(format_markdown(forecast))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
