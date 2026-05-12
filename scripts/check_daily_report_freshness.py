#!/usr/bin/env python3
"""Check whether the daily-report task produced today's durable outputs.

This intentionally avoids using a single git author or commit subject as the
source of truth. The daily-report lane can be completed by GitHub Actions,
Claude Schedule, or a recovery job, so the durable artifacts are the report
file, schedule log, and metrics snapshot.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


GENERATED_MARKERS = (
    "<!-- generated-by: github-actions -->",
    "<!-- generated-by: claude-schedule",
    "daily-report.yml",
)


def jst_today() -> str:
    return datetime.now(ZoneInfo("Asia/Tokyo")).strftime("%Y-%m-%d")


def read_text(root: Path, rel_path: str, ref: str | None) -> str | None:
    if ref:
        # Git paths always use forward slashes, even on Windows.
        git_path = rel_path.replace("\\", "/")
        result = subprocess.run(
            ["git", "show", f"{ref}:{git_path}"],
            cwd=root,
            encoding="utf-8",
            errors="replace",
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode != 0:
            return None
        return result.stdout

    path = root / rel_path
    if not path.exists():
        return None
    return path.read_text(encoding="utf-8")


def load_json(root: Path, rel_path: str, ref: str | None) -> dict[str, Any] | None:
    text = read_text(root, rel_path, ref)
    if text is None:
        return None
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def check(date: str, root: Path, ref: str | None) -> dict[str, Any]:
    report_path = f"docs/daily-reports/{date}.md"
    log_path = f"docs/schedule-logs/daily-report-{date}-00.json"
    metrics_path = "docs/metrics/daily-metrics.json"

    report_text = read_text(root, report_path, ref)
    report_exists = report_text is not None
    report_marker = False
    if report_text is not None:
        report_marker = any(marker in report_text for marker in GENERATED_MARKERS)

    schedule_log = load_json(root, log_path, ref)
    schedule_log_success = False
    if schedule_log:
        expected_saved = schedule_log.get("details", {}).get("daily_report_saved")
        schedule_log_success = (
            schedule_log.get("task_id") == "daily-report"
            and schedule_log.get("status") == "success"
            and (expected_saved in (None, report_path) or str(expected_saved).endswith(f"{date}.md"))
        )

    metrics = load_json(root, metrics_path, ref)
    metrics_match = bool(metrics and metrics.get("report_date") == date)

    # A report file is the durable artifact. The marker/log/metrics are
    # corroborating signals that prevent stale checkout and author-grep mistakes.
    fresh = report_exists and (report_marker or schedule_log_success or metrics_match)

    return {
        "date": date,
        "fresh": fresh,
        "ref": ref or "worktree",
        "signals": {
            "report_exists": report_exists,
            "report_marker": report_marker,
            "schedule_log_success": schedule_log_success,
            "metrics_report_date_matches": metrics_match,
        },
        "paths": {
            "report": report_path,
            "schedule_log": log_path,
            "metrics": metrics_path,
        },
        "reason": "daily-report artifacts are fresh"
        if fresh
        else "missing daily-report report file or corroborating freshness signal",
    }


def write_github_output(path: str | None, result: dict[str, Any]) -> None:
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write(f"fresh={str(result['fresh']).lower()}\n")
        handle.write(f"date={result['date']}\n")
        handle.write(f"reason={result['reason']}\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", default=jst_today(), help="Report date in YYYY-MM-DD (JST default)")
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument("--ref", default=None, help="Optional git ref to inspect, e.g. origin/main")
    parser.add_argument("--json", action="store_true", help="Print machine-readable JSON")
    parser.add_argument(
        "--github-output",
        default=os.environ.get("GITHUB_OUTPUT"),
        help="Optional GitHub Actions output file",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    result = check(args.date, root, args.ref)
    write_github_output(args.github_output, result)

    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        status = "fresh" if result["fresh"] else "stale"
        print(f"daily-report {args.date}: {status} ({result['reason']})")

    return 0 if result["fresh"] else 1


if __name__ == "__main__":
    sys.exit(main())
