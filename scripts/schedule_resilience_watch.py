#!/usr/bin/env python3
"""Retry and alert guard for scheduled GitHub Actions workflows.

The guard watches a small set of production schedules, retries failed scheduled
runs once, and opens/updates a workflow-failure issue when retry is exhausted or
the schedule has stopped producing runs.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.parse import quote, urlencode
from urllib.request import Request, urlopen


OK_CONCLUSIONS = {"success", "skipped", "neutral"}
BAD_CONCLUSIONS = {
    "action_required",
    "cancelled",
    "failure",
    "startup_failure",
    "timed_out",
}


@dataclass(frozen=True)
class WorkflowTarget:
    key: str
    workflow_file: str
    max_age_hours: int


TARGETS = (
    WorkflowTarget("daily-report", "daily-report.yml", 30),
    WorkflowTarget("cs-check", "cs-check.yml", 3),
    WorkflowTarget("competitor-monitoring", "competitor-monitoring.yml", 30),
    WorkflowTarget("infra-health-check", "infra-health-check.yml", 3),
)


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    normalized = value.replace("Z", "+00:00")
    return datetime.fromisoformat(normalized).astimezone(timezone.utc)


def run_url(run: dict[str, Any]) -> str:
    return str(run.get("html_url") or run.get("url") or "")


def evaluate_target(
    target: WorkflowTarget,
    runs: list[dict[str, Any]],
    now: datetime,
    *,
    max_attempts: int,
) -> dict[str, Any]:
    if not runs:
        return {
            "target": target.key,
            "action": "alert",
            "reason": "missing-run",
            "title": f"[Schedule監視] {target.key} missing run",
            "body": (
                f"No scheduled run was found for `{target.workflow_file}`. "
                "This may mean the schedule is disabled or GitHub Actions did "
                "not dispatch it."
            ),
        }

    latest = runs[0]
    status = str(latest.get("status") or "unknown")
    conclusion = str(latest.get("conclusion") or "")
    run_attempt = int(latest.get("run_attempt") or 1)
    created_at = parse_time(str(latest.get("created_at") or ""))
    age_hours = None
    if created_at is not None:
        age_hours = (now - created_at).total_seconds() / 3600

    base = {
        "target": target.key,
        "workflow_file": target.workflow_file,
        "run_id": latest.get("id"),
        "run_attempt": run_attempt,
        "status": status,
        "conclusion": conclusion,
        "url": run_url(latest),
        "created_at": latest.get("created_at"),
        "age_hours": round(age_hours, 2) if age_hours is not None else None,
    }

    if status != "completed":
        return {**base, "action": "observe", "reason": f"run-{status}"}

    if conclusion in OK_CONCLUSIONS:
        if age_hours is not None and age_hours > target.max_age_hours:
            return {
                **base,
                "action": "alert",
                "reason": "stale-success",
                "title": f"[Schedule監視] {target.key} stale schedule",
                "body": (
                    f"Latest scheduled run for `{target.workflow_file}` is "
                    f"{age_hours:.1f}h old, exceeding the {target.max_age_hours}h guard."
                ),
            }
        return {**base, "action": "healthy", "reason": "latest-success"}

    if conclusion in BAD_CONCLUSIONS:
        if run_attempt < max_attempts:
            return {
                **base,
                "action": "retry",
                "reason": f"failed-attempt-{run_attempt}",
            }
        return {
            **base,
            "action": "alert",
            "reason": "retry-exhausted",
            "title": f"[Schedule監視] {target.key} failure",
            "body": (
                f"`{target.workflow_file}` failed after {run_attempt} attempt(s). "
                f"Run: {run_url(latest)}"
            ),
        }

    return {
        **base,
        "action": "alert",
        "reason": f"unexpected-conclusion-{conclusion or 'empty'}",
        "title": f"[Schedule監視] {target.key} unexpected conclusion",
        "body": (
            f"`{target.workflow_file}` ended with unexpected conclusion "
            f"`{conclusion or 'empty'}`. Run: {run_url(latest)}"
        ),
    }


class GitHubClient:
    def __init__(self, repo: str, token: str, *, api_url: str = "https://api.github.com") -> None:
        self.repo = repo
        self.token = token
        self.api_url = api_url.rstrip("/")

    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        data = None if body is None else json.dumps(body).encode("utf-8")
        headers = {
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        request = Request(
            f"{self.api_url}{path}",
            data=data,
            method=method,
            headers=headers,
        )
        with urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8")
            if not payload:
                return {}
            return json.loads(payload)

    def scheduled_runs(self, workflow_file: str, *, limit: int) -> list[dict[str, Any]]:
        query = urlencode({"branch": "main", "event": "schedule", "per_page": str(limit)})
        path = f"/repos/{self.repo}/actions/workflows/{quote(workflow_file)}/runs?{query}"
        payload = self.request("GET", path)
        runs = payload.get("workflow_runs", []) if isinstance(payload, dict) else []
        return runs if isinstance(runs, list) else []

    def rerun_failed_jobs(self, run_id: int) -> None:
        self.request("POST", f"/repos/{self.repo}/actions/runs/{run_id}/rerun-failed-jobs", {})

    def open_or_update_issue(self, title: str, body: str) -> str:
        labels = "workflow-failure"
        issues = self.request(
            "GET",
            f"/repos/{self.repo}/issues?{urlencode({'state': 'open', 'labels': labels, 'per_page': '100'})}",
        )
        if isinstance(issues, list):
            for issue in issues:
                if issue.get("title") == title and "pull_request" not in issue:
                    number = issue.get("number")
                    self.request("POST", f"/repos/{self.repo}/issues/{number}/comments", {"body": body})
                    return str(issue.get("html_url") or "")

        created = self.request(
            "POST",
            f"/repos/{self.repo}/issues",
            {
                "title": title,
                "body": body,
                "labels": ["bug", "automation", "priority:high", "workflow-failure"],
            },
        )
        return str(created.get("html_url") or "")


def issue_body(result: dict[str, Any], now: datetime) -> str:
    lines = [
        "Schedule resilience watch detected a problem.",
        "",
        f"- Target: `{result['target']}`",
        f"- Workflow file: `{result.get('workflow_file', '')}`",
        f"- Reason: `{result['reason']}`",
        f"- Checked at: `{now.isoformat()}`",
    ]
    if result.get("run_id"):
        lines.extend(
            [
                f"- Run ID: `{result['run_id']}`",
                f"- Attempt: `{result.get('run_attempt')}`",
                f"- Status/conclusion: `{result.get('status')}` / `{result.get('conclusion')}`",
                f"- Run: {result.get('url')}",
            ]
        )
    if result.get("body"):
        lines.extend(["", str(result["body"])])
    lines.extend(["", "Codex #1 route: old PS#1 workflow-health lane is absorbed by Codex #1."])
    return "\n".join(lines)


def render_summary(results: list[dict[str, Any]]) -> str:
    lines = [
        "## Schedule Resilience Watch",
        "",
        "| Target | Action | Reason | Run |",
        "|---|---|---|---|",
    ]
    for result in results:
        run = result.get("url") or ""
        run_cell = f"[run]({run})" if run else "-"
        lines.append(
            f"| `{result['target']}` | `{result['action']}` | `{result['reason']}` | {run_cell} |"
        )
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", "kanta13jp1/my_web_app"))
    parser.add_argument("--max-attempts", type=int, default=2)
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--output", default="")
    parser.add_argument("--github-step-summary", default=os.environ.get("GITHUB_STEP_SUMMARY", ""))
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token and not args.dry_run:
        print("GH_TOKEN or GITHUB_TOKEN is required.", file=sys.stderr)
        return 2

    now = datetime.now(timezone.utc)
    client = GitHubClient(args.repo, token or "")
    results: list[dict[str, Any]] = []

    for target in TARGETS:
        runs = client.scheduled_runs(target.workflow_file, limit=args.limit)
        result = evaluate_target(target, runs, now, max_attempts=args.max_attempts)

        if result["action"] == "retry":
            if args.dry_run:
                result["write"] = "dry-run-rerun"
            else:
                try:
                    client.rerun_failed_jobs(int(result["run_id"]))
                    result["write"] = "rerun-failed-jobs"
                except HTTPError as exc:
                    result["action"] = "alert"
                    result["reason"] = f"rerun-failed-http-{exc.code}"
                    result["title"] = f"[Schedule監視] {target.key} rerun failed"
                    result["body"] = f"Failed to rerun `{target.workflow_file}` via GitHub API: HTTP {exc.code}."

        if result["action"] == "alert":
            body = issue_body(result, now)
            if args.dry_run:
                result["issue_url"] = "dry-run"
            else:
                result["issue_url"] = client.open_or_update_issue(str(result["title"]), body)

        results.append(result)

    summary = render_summary(results)
    print(summary)

    if args.github_step_summary:
        with Path(args.github_step_summary).open("a", encoding="utf-8") as handle:
            handle.write(summary)
    if args.output:
        Path(args.output).write_text(
            json.dumps({"checked_at": now.isoformat(), "results": results}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
