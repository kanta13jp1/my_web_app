#!/usr/bin/env python3
"""Manage 30-day grace handling for dormant instance issues.

The active fleet is Claude Code #1 + Codex #1. Historical instance labels such
as vscode-instance or ps1-instance should not be closed immediately; this script
posts a grace notice after WARN_DAYS and closes only after GRACE_DAYS when there
is no recurrence signal.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any


DEFAULT_DORMANT_LABELS = (
    "vscode-instance",
    "ps1-instance",
    "ps2-instance",
    "ps3-instance",
    "ps4-instance",
    "ps5-instance",
    "ps6-instance",
    "web-instance",
    "mobile-instance",
    "codex1-instance",
    "codex2-instance",
)

SKIP_LABELS = {"workflow-failure"}
GRACE_MARKER = "<!-- dormant-instance-grace:v1 -->"
CLOSE_MARKER = "<!-- dormant-instance-auto-close:v1 -->"

RECURRENCE_KEYWORDS = (
    "reproduce",
    "reproduced",
    "still happens",
    "still happening",
    "happen again",
    "happens again",
    "happened again",
    "recurs",
    "recurring",
    "再現",
    "再発",
)

NON_RECURRENCE_MARKERS = (
    "no recurrence",
    "no reproduction",
    "reproduction: none",
    "reproduce if",
    "if this recurs",
    "再現なし",
    "再現 0",
    "再現 comment 0",
    "再現報告 0",
    "再現時",
    "再現したら",
)


@dataclass
class Decision:
    number: int
    title: str
    url: str
    label: str
    age_days: int
    action: str
    reason: str


def parse_bool(value: str | bool) -> bool:
    if isinstance(value, bool):
        return value
    return value.strip().lower() in {"1", "true", "yes", "on"}


def parse_datetime(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def dormant_labels_from_env() -> list[str]:
    labels = os.environ.get("DORMANT_LABELS")
    if not labels:
        return list(DEFAULT_DORMANT_LABELS)
    return [label.strip() for label in labels.split(",") if label.strip()]


def label_names(issue: dict[str, Any]) -> set[str]:
    return {
        label.get("name", "")
        for label in issue.get("labels", [])
        if isinstance(label, dict)
    }


def has_grace_comment(comments: list[dict[str, Any]]) -> bool:
    for comment in comments:
        body = comment.get("body", "")
        if GRACE_MARKER in body:
            return True
        if "Dormant Instance Grace Status" in body:
            return True
        if "dormant instance grace status" in body.lower():
            return True
    return False


def is_recurrence_comment(comment: dict[str, Any]) -> bool:
    body = comment.get("body", "")
    lowered = body.lower()
    if GRACE_MARKER in body or CLOSE_MARKER in body:
        return False
    if "dormant instance grace" in lowered:
        return False
    if any(marker in lowered for marker in NON_RECURRENCE_MARKERS):
        return False
    return any(keyword in lowered for keyword in RECURRENCE_KEYWORDS)


def has_recurrence_comment(comments: list[dict[str, Any]]) -> bool:
    return any(is_recurrence_comment(comment) for comment in comments)


def decide_issue(
    issue: dict[str, Any],
    matched_label: str,
    now: datetime,
    warn_days: int,
    grace_days: int,
) -> Decision:
    labels = label_names(issue)
    created = parse_datetime(issue["createdAt"])
    age_days = (now - created).days
    comments = issue.get("comments", [])
    number = int(issue["number"])
    title = issue.get("title", "")
    url = issue.get("url", "")

    if labels & SKIP_LABELS:
        return Decision(
            number,
            title,
            url,
            matched_label,
            age_days,
            "skip",
            "workflow-failure label present",
        )

    if has_recurrence_comment(comments):
        return Decision(
            number,
            title,
            url,
            matched_label,
            age_days,
            "skip",
            "recurrence comment present",
        )

    if age_days >= grace_days:
        return Decision(
            number,
            title,
            url,
            matched_label,
            age_days,
            "close",
            f"age {age_days}d >= grace {grace_days}d",
        )

    if age_days >= warn_days:
        if has_grace_comment(comments):
            return Decision(
                number,
                title,
                url,
                matched_label,
                age_days,
                "noop",
                "grace comment already present",
            )
        return Decision(
            number,
            title,
            url,
            matched_label,
            age_days,
            "warn",
            f"age {age_days}d >= warn {warn_days}d",
        )

    return Decision(
        number,
        title,
        url,
        matched_label,
        age_days,
        "noop",
        f"age {age_days}d < warn {warn_days}d",
    )


def run_gh(args: list[str]) -> str:
    completed = subprocess.run(
        ["gh", *args],
        check=True,
        capture_output=True,
        encoding="utf-8",
        text=True,
    )
    return completed.stdout


def fetch_issues_for_label(repo: str, label: str) -> list[dict[str, Any]]:
    raw = run_gh(
        [
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "open",
            "--label",
            label,
            "--limit",
            "200",
            "--json",
            "number,title,createdAt,labels,url",
        ]
    )
    return json.loads(raw)


def fetch_issue_details(repo: str, number: int) -> dict[str, Any]:
    raw = run_gh(
        [
            "issue",
            "view",
            str(number),
            "--repo",
            repo,
            "--comments",
            "--json",
            "number,title,createdAt,labels,comments,url",
        ]
    )
    return json.loads(raw)


def collect_dormant_issues(repo: str, labels: list[str]) -> list[tuple[dict[str, Any], str]]:
    seen: dict[int, tuple[dict[str, Any], str]] = {}
    for label in labels:
        for issue in fetch_issues_for_label(repo, label):
            number = int(issue["number"])
            if number in seen:
                continue
            seen[number] = (fetch_issue_details(repo, number), label)
    return list(seen.values())


def warn_body(decision: Decision, issue: dict[str, Any], warn_days: int, grace_days: int) -> str:
    created = parse_datetime(issue["createdAt"])
    expiry = created + timedelta(days=grace_days)
    remaining = max(grace_days - decision.age_days, 0)
    return f"""{GRACE_MARKER}
## Dormant Instance Grace Status

This issue has dormant instance label `{decision.label}`. Current active routing
is Claude Code #1 + Codex #1, so dormant-instance issues enter a {grace_days}-day
grace window instead of being closed immediately.

- Created: {created.date().isoformat()} ({decision.age_days} days ago)
- Grace warning threshold: {warn_days} days
- Planned close date: {expiry.date().isoformat()} ({remaining} days remaining)

If the same problem reproduces in the current 2-instance fleet, please add a
recurrence comment and replace the dormant label with `claude-code-instance` or
`codex-instance`.
"""


def close_body(decision: Decision, issue: dict[str, Any], grace_days: int) -> str:
    created = parse_datetime(issue["createdAt"])
    return f"""{CLOSE_MARKER}
## Dormant Instance Auto-Close

This issue has dormant instance label `{decision.label}` and is
{decision.age_days} days old. No recurrence signal was found during the
{grace_days}-day grace window for the active Claude Code #1 + Codex #1 fleet.

Reopen and relabel to `claude-code-instance` or `codex-instance` if it reproduces
again in the current fleet.

Created: {created.date().isoformat()}
"""


def apply_decision(
    repo: str,
    decision: Decision,
    issue: dict[str, Any],
    warn_days: int,
    grace_days: int,
    apply: bool,
) -> None:
    if not apply:
        return
    if decision.action == "warn":
        run_gh(
            [
                "issue",
                "comment",
                str(decision.number),
                "--repo",
                repo,
                "--body",
                warn_body(decision, issue, warn_days, grace_days),
            ]
        )
    elif decision.action == "close":
        run_gh(
            [
                "issue",
                "close",
                str(decision.number),
                "--repo",
                repo,
                "--comment",
                close_body(decision, issue, grace_days),
            ]
        )


def render_summary(report: dict[str, Any]) -> str:
    lines = [
        "# Dormant Instance Grace Report",
        "",
        f"- repo: `{report['repo']}`",
        f"- apply: `{str(report['apply']).lower()}`",
        f"- scanned issues: {report['scanned_issues']}",
        f"- warn: {report['counts'].get('warn', 0)}",
        f"- close: {report['counts'].get('close', 0)}",
        f"- skip: {report['counts'].get('skip', 0)}",
        f"- noop: {report['counts'].get('noop', 0)}",
        "",
        "| issue | label | age | action | reason |",
        "| --- | --- | ---: | --- | --- |",
    ]
    for decision in report["decisions"]:
        issue = f"[#{decision['number']}]({decision['url']})"
        lines.append(
            f"| {issue} | `{decision['label']}` | {decision['age_days']} | "
            f"`{decision['action']}` | {decision['reason']} |"
        )
    lines.append("")
    return "\n".join(lines)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", "kanta13jp1/my_web_app"))
    parser.add_argument("--apply", default="false", help="true to comment/close, false for dry-run")
    parser.add_argument("--labels", help="Comma-separated dormant labels override")
    parser.add_argument("--warn-days", type=int, default=int(os.environ.get("WARN_DAYS", "14")))
    parser.add_argument("--grace-days", type=int, default=int(os.environ.get("GRACE_DAYS", "30")))
    parser.add_argument("--output", type=Path)
    parser.add_argument("--github-step-summary", type=Path)
    parser.add_argument("--now", help="ISO timestamp override for tests/manual dry-runs")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parse_args(argv)
    apply = parse_bool(args.apply)
    labels = (
        [label.strip() for label in args.labels.split(",") if label.strip()]
        if args.labels
        else dormant_labels_from_env()
    )
    now = parse_datetime(args.now) if args.now else datetime.now(timezone.utc)
    issues = collect_dormant_issues(args.repo, labels)

    decisions: list[Decision] = []
    issue_by_number = {int(issue["number"]): issue for issue, _label in issues}
    for issue, matched_label in issues:
        decision = decide_issue(
            issue,
            matched_label,
            now,
            warn_days=args.warn_days,
            grace_days=args.grace_days,
        )
        apply_decision(
            args.repo,
            decision,
            issue,
            warn_days=args.warn_days,
            grace_days=args.grace_days,
            apply=apply,
        )
        decisions.append(decision)

    counts: dict[str, int] = {}
    for decision in decisions:
        counts[decision.action] = counts.get(decision.action, 0) + 1

    report = {
        "repo": args.repo,
        "apply": apply,
        "labels": labels,
        "warn_days": args.warn_days,
        "grace_days": args.grace_days,
        "scanned_issues": len(issue_by_number),
        "counts": counts,
        "decisions": [asdict(decision) for decision in decisions],
    }

    summary = render_summary(report)
    print(summary)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")
    if args.github_step_summary:
        args.github_step_summary.parent.mkdir(parents=True, exist_ok=True)
        args.github_step_summary.write_text(summary, encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
