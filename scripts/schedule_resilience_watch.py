#!/usr/bin/env python3
"""Retry and alert guard for production GitHub Actions workflows.

The guard watches a small set of scheduled and deployment workflows, retries
failed runs once, and opens/updates a workflow-failure issue when retry is
exhausted or an expected schedule has stopped producing runs.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
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
REPOSITORY_RUNS_PER_PAGE = 100
REPOSITORY_RUNS_MAX_PAGES = 10
# Keep stale runs visible long enough to classify them instead of reporting them missing.
REPOSITORY_REVALIDATION_MIN_HOURS = 24


@dataclass(frozen=True)
class WorkflowTarget:
    key: str
    workflow_file: str
    max_age_hours: int
    event: str = "schedule"
    introduced_at: datetime | None = None
    require_bootstrap_success: bool = False


TARGETS = (
    WorkflowTarget("daily-report", "daily-report.yml", 30),
    # A two-hour GitHub schedule may be delayed or drop an individual run.
    # Require two missed delivery opportunities before opening a high-priority alert.
    WorkflowTarget("cs-check", "cs-check.yml", 6),
    WorkflowTarget("competitor-monitoring", "competitor-monitoring.yml", 30),
    # A two-hour GitHub schedule may be delayed or drop an individual run.
    # Require two missed delivery opportunities before opening a high-priority alert.
    WorkflowTarget("health-monitor", "health-monitor.yml", 6),
    WorkflowTarget("notion-sync", "notion-sync.yml", 10),
    WorkflowTarget(
        "supabase-backup-restore",
        "supabase-backup-restore.yml",
        192,
        introduced_at=datetime(2026, 8, 26, 6, 35, 33, tzinfo=timezone.utc),
        require_bootstrap_success=True,
    ),
    WorkflowTarget("deploy-prod", "deploy-prod.yml", 0, "push"),
)


def parse_time(value: str | None) -> datetime | None:
    if not value:
        return None
    normalized = value.replace("Z", "+00:00")
    return datetime.fromisoformat(normalized).astimezone(timezone.utc)


def run_url(run: dict[str, Any]) -> str:
    return str(run.get("html_url") or run.get("url") or "")


def sort_runs_newest(runs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    def key(run: dict[str, Any]) -> tuple[datetime, int]:
        created_at = parse_time(str(run.get("created_at") or ""))
        if created_at is None:
            raise ValueError("Workflow run is missing created_at")
        return (
            created_at,
            int(run.get("id") or 0),
        )

    return sorted(runs, key=key, reverse=True)


def workflow_path_matches(path: object, workflow_file: str) -> bool:
    actual = str(path or "").split("@", 1)[0]
    return actual == f".github/workflows/{workflow_file}"


def merge_runs(*run_groups: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: dict[object, dict[str, Any]] = {}
    anonymous_index = 0
    for runs in run_groups:
        for run in runs:
            run_id = run.get("id")
            key: object = run_id if run_id is not None else f"anonymous-{anonymous_index}"
            anonymous_index += 1
            merged[key] = run
    return sort_runs_newest(list(merged.values()))


def repository_revalidation_start(
    target: WorkflowTarget,
    runs: list[dict[str, Any]],
    now: datetime,
) -> datetime:
    if runs:
        newest = sort_runs_newest(runs)[0]
        created_at = parse_time(str(newest.get("created_at") or ""))
        if created_at is None:
            raise ValueError("Workflow run is missing created_at")
        return created_at - timedelta(seconds=1)

    window_hours = (
        max(target.max_age_hours, REPOSITORY_REVALIDATION_MIN_HOURS)
        if target.max_age_hours > 0
        else 24 * 30
    )
    window_start = now - timedelta(hours=window_hours)
    if target.introduced_at is None:
        return window_start
    return max(target.introduced_at, window_start)


def merge_revalidated_runs(
    primary_runs: list[dict[str, Any]],
    repository_runs: list[dict[str, Any]],
    *,
    created_after: datetime,
) -> list[dict[str, Any]]:
    primary_runs = sort_runs_newest(primary_runs)
    repository_runs = sort_runs_newest(repository_runs)
    if primary_runs:
        primary = primary_runs[0]
        primary_created_at = parse_time(str(primary.get("created_at") or ""))
        if primary_created_at is None:
            raise ValueError("Workflow run is missing created_at")
        if primary_created_at >= created_after:
            primary_id = primary.get("id")
            if primary_id is None or not any(
                candidate.get("id") == primary_id for candidate in repository_runs
            ):
                raise RuntimeError("Repository run listing did not confirm the primary latest run")
            return merge_runs(primary_runs, repository_runs)
    return repository_runs


def issue_labels(issue: dict[str, Any]) -> set[str]:
    labels = issue.get("labels")
    if not isinstance(labels, list):
        return set()
    return {
        str(label.get("name") or "")
        for label in labels
        if isinstance(label, dict)
    }


def is_schedule_watch_issue(issue: dict[str, Any], target: WorkflowTarget) -> bool:
    if "pull_request" in issue:
        return False
    if not {"workflow-failure", "automation"}.issubset(issue_labels(issue)):
        return False
    user = issue.get("user")
    if not isinstance(user, dict) or str(user.get("login") or "") != "github-actions[bot]":
        return False

    allowed_titles = {
        f"[Schedule監視] {target.key} missing run",
        f"[Schedule監視] {target.key} stale schedule",
        f"[Schedule監視] {target.key} failure",
        f"[Schedule監視] {target.key} unexpected conclusion",
        f"[Schedule監視] {target.key} rerun failed",
        f"[Schedule監視] {target.key} workflow disabled",
        f"[Schedule監視] {target.key} stuck run",
    }
    if str(issue.get("title") or "") not in allowed_titles:
        return False

    body = str(issue.get("body") or "")
    marker_target = re.search(
        r"(?m)^<!-- schedule_resilience_target: ([^\r\n]+) -->$",
        body,
    )
    marker_workflow = re.search(
        r"(?m)^<!-- schedule_resilience_workflow: ([^\r\n]+) -->$",
        body,
    )
    if marker_target or marker_workflow:
        return (
            marker_target is not None
            and marker_target.group(1) == target.key
            and marker_workflow is not None
            and marker_workflow.group(1) == target.workflow_file
        )

    if not body.startswith("Schedule resilience watch detected a problem.\n"):
        return False
    legacy_target = re.search(r"(?m)^- Target: `([^`\r\n]+)`$", body)
    legacy_workflow = re.search(r"(?m)^- Workflow file: `([^`\r\n]+)`$", body)
    return (
        legacy_target is not None
        and legacy_target.group(1) == target.key
        and legacy_workflow is not None
        and legacy_workflow.group(1) == target.workflow_file
    )


def evaluate_target(
    target: WorkflowTarget,
    runs: list[dict[str, Any]],
    now: datetime,
    *,
    max_attempts: int,
    fallback_runs: list[dict[str, Any]] | None = None,
    workflow_state: str = "active",
) -> dict[str, Any]:
    runs = sort_runs_newest(runs)
    fallback_runs = sort_runs_newest(fallback_runs or [])
    if not runs:
        if workflow_state != "active":
            return {
                "target": target.key,
                "workflow_file": target.workflow_file,
                "action": "alert",
                "reason": "workflow-disabled",
                "title": f"[Schedule監視] {target.key} workflow disabled",
                "body": (
                    f"`{target.workflow_file}` is `{workflow_state}` and cannot "
                    f"produce the expected `{target.event}` run."
                ),
            }

        latest_fallback = (fallback_runs or [None])[0]
        grace_deadline = (
            target.introduced_at
            + timedelta(hours=target.max_age_hours)
            if target.introduced_at is not None and target.max_age_hours > 0
            else None
        )
        if (
            target.require_bootstrap_success
            and isinstance(latest_fallback, dict)
            and target.introduced_at is not None
            and grace_deadline is not None
        ):
            fallback_created_at = parse_time(str(latest_fallback.get("created_at") or ""))
            if (
                now < grace_deadline
                and fallback_created_at is not None
                and fallback_created_at >= target.introduced_at
                and str(latest_fallback.get("event") or "") == "workflow_dispatch"
                and str(latest_fallback.get("status") or "") == "completed"
                and str(latest_fallback.get("conclusion") or "") == "success"
            ):
                return {
                    "target": target.key,
                    "workflow_file": target.workflow_file,
                    "run_id": latest_fallback.get("id"),
                    "run_attempt": int(latest_fallback.get("run_attempt") or 1),
                    "status": "completed",
                    "conclusion": "success",
                    "url": run_url(latest_fallback),
                    "created_at": latest_fallback.get("created_at"),
                    "action": "observe",
                    "reason": "awaiting-first-scheduled-run",
                    "grace_deadline": grace_deadline.isoformat(),
                }
        return {
            "target": target.key,
            "workflow_file": target.workflow_file,
            "action": "alert",
            "reason": "missing-run",
            "title": f"[Schedule監視] {target.key} missing run",
            "body": (
                f"No run was found for `{target.workflow_file}`. "
                f"Expected event: `{target.event}`. This may mean the workflow "
                "is disabled or GitHub Actions did not dispatch it."
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
        if (
            target.max_age_hours > 0
            and age_hours is not None
            and age_hours > target.max_age_hours
        ):
            return {
                **base,
                "action": "alert",
                "reason": f"stuck-run-{status}",
                "title": f"[Schedule監視] {target.key} stuck run",
                "body": (
                    f"`{target.workflow_file}` has remained `{status}` for "
                    f"{age_hours:.1f}h, exceeding the {target.max_age_hours}h guard."
                ),
            }
        return {**base, "action": "observe", "reason": f"run-{status}"}

    if conclusion in OK_CONCLUSIONS:
        if target.require_bootstrap_success and conclusion != "success":
            return {
                **base,
                "action": "alert",
                "reason": f"unexpected-conclusion-{conclusion}",
                "title": f"[Schedule監視] {target.key} unexpected conclusion",
                "body": (
                    f"`{target.workflow_file}` requires a successful backup run, "
                    f"but the latest conclusion was `{conclusion}`."
                ),
            }
        if (
            target.max_age_hours > 0
            and age_hours is not None
            and age_hours > target.max_age_hours
        ):
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
        if (
            target.max_age_hours > 0
            and age_hours is not None
            and age_hours > target.max_age_hours
        ):
            return {
                **base,
                "action": "alert",
                "reason": "stale-failure",
                "title": f"[Schedule監視] {target.key} stale schedule",
                "body": (
                    f"Latest scheduled run for `{target.workflow_file}` failed and is "
                    f"{age_hours:.1f}h old, exceeding the {target.max_age_hours}h guard. "
                    f"Run: {run_url(latest)}"
                ),
            }
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
            "User-Agent": "my-web-app-schedule-resilience-watch",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if method == "GET":
            headers["Cache-Control"] = "no-cache"
            headers["Pragma"] = "no-cache"
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

    def workflow_runs(
        self,
        workflow_file: str,
        *,
        event: str | None,
        limit: int,
    ) -> list[dict[str, Any]]:
        query_params = {"branch": "main", "per_page": str(limit)}
        if event:
            query_params["event"] = event
        query = urlencode(query_params)
        path = f"/repos/{self.repo}/actions/workflows/{quote(workflow_file)}/runs?{query}"
        payload = self.request("GET", path)
        runs = payload.get("workflow_runs", []) if isinstance(payload, dict) else []
        return sort_runs_newest(runs) if isinstance(runs, list) else []

    def repository_workflow_runs(
        self,
        workflow_file: str,
        *,
        event: str,
        created_after: datetime,
    ) -> list[dict[str, Any]]:
        matches: list[dict[str, Any]] = []
        for page in range(1, REPOSITORY_RUNS_MAX_PAGES + 1):
            query = urlencode(
                {
                    "branch": "main",
                    "event": event,
                    "created": f">={created_after.astimezone(timezone.utc).isoformat()}",
                    "per_page": str(REPOSITORY_RUNS_PER_PAGE),
                    "page": str(page),
                }
            )
            payload = self.request("GET", f"/repos/{self.repo}/actions/runs?{query}")
            page_runs = payload.get("workflow_runs", []) if isinstance(payload, dict) else []
            if not isinstance(page_runs, list):
                raise RuntimeError("Repository workflow runs response is invalid")
            matches.extend(
                run
                for run in page_runs
                if isinstance(run, dict) and workflow_path_matches(run.get("path"), workflow_file)
            )
            if len(page_runs) < REPOSITORY_RUNS_PER_PAGE:
                return sort_runs_newest(matches)
        raise RuntimeError("Repository workflow runs pagination was incomplete")

    def workflow_state(self, workflow_file: str) -> str:
        path = f"/repos/{self.repo}/actions/workflows/{quote(workflow_file)}"
        payload = self.request("GET", path)
        return str(payload.get("state") or "unknown") if isinstance(payload, dict) else "unknown"

    def rerun_failed_jobs(self, run_id: int) -> None:
        self.request("POST", f"/repos/{self.repo}/actions/runs/{run_id}/rerun-failed-jobs", {})

    def open_workflow_failure_issues(self) -> list[dict[str, Any]]:
        issues: list[dict[str, Any]] = []
        for page in range(1, 11):
            query = urlencode(
                {
                    "state": "open",
                    "labels": "workflow-failure",
                    "per_page": "100",
                    "page": str(page),
                }
            )
            payload = self.request("GET", f"/repos/{self.repo}/issues?{query}")
            if not isinstance(payload, list):
                raise RuntimeError("Open workflow-failure Issue response is invalid")
            issues.extend(issue for issue in payload if isinstance(issue, dict))
            if len(payload) < 100:
                return issues
        raise RuntimeError("Open workflow-failure Issue pagination was incomplete")

    def open_or_update_issue(
        self,
        target: WorkflowTarget,
        title: str,
        body: str,
    ) -> str:
        for issue in self.open_workflow_failure_issues():
            if is_schedule_watch_issue(issue, target):
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

    def issue_comments(self, issue_number: int) -> list[dict[str, Any]]:
        comments: list[dict[str, Any]] = []
        for page in range(1, 11):
            query = urlencode({"per_page": "100", "page": str(page)})
            payload = self.request(
                "GET",
                f"/repos/{self.repo}/issues/{issue_number}/comments?{query}",
            )
            if not isinstance(payload, list):
                raise RuntimeError("Issue comments response is invalid")
            comments.extend(comment for comment in payload if isinstance(comment, dict))
            if len(payload) < 100:
                return comments
        raise RuntimeError("Issue comments pagination was incomplete")

    def close_recovered_issues(
        self,
        target: WorkflowTarget,
        result: dict[str, Any],
        now: datetime,
    ) -> list[str]:
        closed: list[str] = []
        for issue in self.open_workflow_failure_issues():
            number = issue.get("number")
            if not is_schedule_watch_issue(issue, target) or not isinstance(number, int):
                continue

            recovery_marker = f"<!-- schedule_resilience_recovery: {target.key} -->"
            comment = "\n".join(
                [
                    "Schedule resilience watch confirmed a healthy monitoring state.",
                    "",
                    f"- Target: `{target.key}`",
                    f"- Workflow file: `{target.workflow_file}`",
                    f"- Recovery reason: `{result.get('reason', 'healthy')}`",
                    f"- Status/conclusion: `{result.get('status')}` / `{result.get('conclusion')}`",
                    f"- Checked at: `{now.isoformat()}`",
                    f"- Run: {result.get('url') or 'not applicable'}",
                    "",
                    "Closing this workflow-failure alert automatically. "
                    "A later regression will open a new canonical alert.",
                    recovery_marker,
                ]
            )
            existing_comments = self.issue_comments(number)
            if not any(
                recovery_marker in str(existing.get("body") or "")
                for existing in existing_comments
            ):
                self.request(
                    "POST",
                    f"/repos/{self.repo}/issues/{number}/comments",
                    {"body": comment},
                )
            self.request(
                "PATCH",
                f"/repos/{self.repo}/issues/{number}",
                {"state": "closed", "state_reason": "completed"},
            )
            closed.append(str(issue.get("html_url") or ""))
        return closed


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
    lines.extend(
        [
            "",
            "Codex #1 route: old PS#1 workflow-health lane is absorbed by Codex #1.",
            "<!-- schedule_resilience_issue: v1 -->",
            f"<!-- schedule_resilience_target: {result['target']} -->",
            f"<!-- schedule_resilience_workflow: {result.get('workflow_file', '')} -->",
        ]
    )
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
        primary_error = ""
        try:
            try:
                primary_runs = client.workflow_runs(
                    target.workflow_file,
                    event=target.event,
                    limit=args.limit,
                )
            except (HTTPError, URLError, RuntimeError, ValueError) as exc:
                primary_runs = []
                primary_error = type(exc).__name__

            created_after = repository_revalidation_start(target, primary_runs, now)
            repository_runs = client.repository_workflow_runs(
                target.workflow_file,
                event=target.event,
                created_after=created_after,
            )
            runs = merge_revalidated_runs(
                primary_runs,
                repository_runs,
                created_after=created_after,
            )
            if target.max_age_hours <= 0 and not runs:
                raise RuntimeError("Event-driven workflow freshness could not be verified")

            should_bootstrap = not runs and target.event == "schedule"
            fallback_runs = (
                client.repository_workflow_runs(
                    target.workflow_file,
                    event="workflow_dispatch",
                    created_after=repository_revalidation_start(target, [], now),
                )
                if should_bootstrap and target.require_bootstrap_success
                else []
            )
            workflow_state = (
                client.workflow_state(target.workflow_file) if should_bootstrap else "active"
            )
        except (HTTPError, URLError, RuntimeError, ValueError) as exc:
            results.append(
                {
                    "target": target.key,
                    "workflow_file": target.workflow_file,
                    "action": "observe",
                    "reason": "freshness-unverified",
                    "verification_error": type(exc).__name__,
                }
            )
            continue

        result = evaluate_target(
            target,
            runs,
            now,
            max_attempts=args.max_attempts,
            fallback_runs=fallback_runs,
            workflow_state=workflow_state,
        )
        if primary_error:
            result["primary_verification_error"] = primary_error

        if result["action"] == "retry":
            if args.dry_run:
                result["write"] = "dry-run-rerun"
            else:
                try:
                    client.rerun_failed_jobs(int(result["run_id"]))
                    result["write"] = "rerun-failed-jobs"
                except (HTTPError, URLError, RuntimeError) as exc:
                    result["action"] = "alert"
                    error_name = (
                        f"http-{exc.code}" if isinstance(exc, HTTPError) else type(exc).__name__.lower()
                    )
                    result["reason"] = f"rerun-failed-{error_name}"
                    result["title"] = f"[Schedule監視] {target.key} rerun failed"
                    result["body"] = (
                        f"Failed to rerun `{target.workflow_file}` via GitHub API: {error_name}."
                    )

        if result["action"] == "alert":
            body = issue_body(result, now)
            if args.dry_run:
                result["issue_url"] = "dry-run"
            else:
                try:
                    result["issue_url"] = client.open_or_update_issue(
                        target,
                        str(result["title"]),
                        body,
                    )
                except (HTTPError, URLError, RuntimeError) as exc:
                    result["issue_write_error"] = (
                        f"HTTP {exc.code}" if isinstance(exc, HTTPError) else type(exc).__name__
                    )
        elif (
            result["action"] == "healthy"
            and result.get("status") == "completed"
            and result.get("conclusion") == "success"
        ):
            if args.dry_run:
                result["recovered_issues"] = "dry-run"
            else:
                try:
                    result["recovered_issues"] = client.close_recovered_issues(target, result, now)
                except (HTTPError, URLError, RuntimeError) as exc:
                    result["recovery_close_error"] = (
                        f"HTTP {exc.code}" if isinstance(exc, HTTPError) else type(exc).__name__
                    )

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
    has_operational_error = any(
        result.get("reason") == "freshness-unverified"
        or "issue_write_error" in result
        or "recovery_close_error" in result
        for result in results
    )
    return 1 if has_operational_error else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
