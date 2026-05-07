#!/usr/bin/env python3
"""Generate a two-instance execution plan for WBS/GitHub Issue tasks."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


ROLE_TEMPLATES = [
    {
        "role": "Claude Code #1",
        "owns": "architecture, boundary decisions, exception policy, high-risk review",
        "may_write": [
            "docs/architecture/",
            "docs/adr/",
            "docs/issue-fix-plans/",
            "review comments and handoff packets",
        ],
        "must_not_write": [
            "Codex #1 task worktree files while implementation is in progress",
            "production deploy changes without an explicit design note",
        ],
    },
    {
        "role": "Codex #1",
        "owns": "fresh worktree, scoped implementation, local verification, PR/deploy follow-through",
        "may_write": [
            "issue-scoped scripts/docs/tests/workflows",
            "the task branch and PR body",
            "cleanup notes after merge",
        ],
        "must_not_write": [
            "dirty primary-worktree files",
            "Claude Code #1 worktrees",
            "secrets or local credentials",
        ],
    },
    {
        "role": "GitHub Actions",
        "owns": "required checks, artifacts, deploy result, non-agent evidence",
        "may_write": [
            "job summary",
            "uploaded artifacts",
            "optional issue or PR comment when explicitly enabled",
        ],
        "must_not_write": [
            "protected branches",
            "approval or merge decisions",
        ],
    },
    {
        "role": "User/Automation",
        "owns": "manual decisions, schedule-only work, blocked-item routing",
        "may_write": [
            "WBS status and owner decisions",
            "requested manual approvals",
        ],
        "must_not_write": [
            "implementation patches without a human-operated instance owner",
        ],
    },
]

CLAUDE_KEYWORDS = (
    r"\barchitecture\b",
    r"\bdesign\b",
    r"\breview\b",
    r"\bsecurity\b",
    r"\bauth\b",
    r"\bpayment\b",
    r"\bbilling\b",
    r"\blegal\b",
    r"\btax\b",
    r"\bsecret\b",
    r"\bcredential\b",
    r"\bpolicy\b",
    r"\bultrareview\b",
)

BLOCKED_KEYWORDS = (
    r"\bblocked\b",
    r"\bblocker\b",
    r"\bwaiting\b",
    r"\buser decision\b",
    r"\bmanual\b",
    r"\bowner decision\b",
)

AUTOMATION_KEYWORDS = (
    r"\bworkflow\b",
    r"\bci\b",
    r"\bgithub actions\b",
    r"\bautomation\b",
    r"\bwbs sync\b",
    r"\bwbs automation\b",
    r"\bschedule\b",
    r"\bharness\b",
)

UI_KEYWORDS = (
    r"\bui\b",
    r"\bux\b",
    r"\bflutter\b",
    r"\bvisual\b",
    r"\bplaywright\b",
    r"\be2e\b",
)

DATA_KEYWORDS = (
    r"\bsql\b",
    r"\bmigration\b",
    r"\bsupabase\b",
    r"\brls\b",
    r"\bservice[_ -]?role\b",
    r"\bedge function\b",
)

DATE_PATTERNS = (
    re.compile(r"due[:= ]+(?P<date>20\d{2}[-/]\d{1,2}[-/]\d{1,2})", re.IGNORECASE),
    re.compile(r"deadline[:= ]+(?P<date>20\d{2}[-/]\d{1,2}[-/]\d{1,2})", re.IGNORECASE),
    re.compile(r"(?:due|deadline)\s+(?P<date>20\d{2}[-/]\d{1,2}[-/]\d{1,2})", re.IGNORECASE),
    re.compile(r"(?:期限|完了予定)[:= ]*(?P<date>20\d{2}[-/]\d{1,2}[-/]\d{1,2})"),
)


def matches(patterns: tuple[str, ...], text: str) -> bool:
    return any(re.search(pattern, text, flags=re.IGNORECASE) for pattern in patterns)


def label_names(labels: list[dict[str, Any]] | list[str] | None) -> set[str]:
    names: set[str] = set()
    for label in labels or []:
        if isinstance(label, str):
            names.add(label.lower())
        elif isinstance(label, dict) and isinstance(label.get("name"), str):
            names.add(label["name"].lower())
    return names


def comment_text(issue: dict[str, Any]) -> str:
    comments = issue.get("comments") or []
    bodies: list[str] = []
    for comment in comments:
        if isinstance(comment, dict) and isinstance(comment.get("body"), str):
            bodies.append(comment["body"])
    return "\n".join(bodies)


def latest_comment(issue: dict[str, Any]) -> dict[str, str] | None:
    comments = issue.get("comments") or []
    parsed: list[dict[str, str]] = []
    for comment in comments:
        if not isinstance(comment, dict):
            continue
        created_at = str(comment.get("createdAt") or "")
        body = str(comment.get("body") or "")
        url = str(comment.get("url") or "")
        if created_at or body:
            parsed.append({"created_at": created_at, "body": body, "url": url})
    if not parsed:
        return None
    return sorted(parsed, key=lambda item: item["created_at"])[-1]


def task_text(issue: dict[str, Any]) -> str:
    return f"{issue.get('title', '')}\n{issue.get('body', '')}\n{comment_text(issue)}"


def title_body_text(issue: dict[str, Any]) -> str:
    return f"{issue.get('title', '')}\n{issue.get('body', '')}"


def parse_due_date(issue: dict[str, Any]) -> str | None:
    explicit = issue.get("due") or issue.get("due_date") or issue.get("deadline")
    if isinstance(explicit, str):
        parsed = parse_date_value(explicit)
        if parsed:
            return parsed
    for pattern in DATE_PATTERNS:
        for match in pattern.finditer(task_text(issue)):
            parsed = parse_date_value(match.group("date"))
            if parsed:
                return parsed
    return None


def parse_date_value(value: str) -> str | None:
    normalized = value.strip().replace("/", "-")
    parts = normalized.split("-")
    if len(parts) != 3:
        return None
    try:
        year, month, day = (int(part) for part in parts)
        return dt.date(year, month, day).isoformat()
    except ValueError:
        return None


def task_kind(issue: dict[str, Any]) -> str:
    text = title_body_text(issue)
    comments = comment_text(issue)
    labels = label_names(issue.get("labels"))
    if matches(BLOCKED_KEYWORDS, f"{text}\n{comments}"):
        return "blocked_or_manual"
    if labels & {"security", "supabase", "edge-function"} or matches(DATA_KEYWORDS, text):
        return "data_or_security"
    if matches(CLAUDE_KEYWORDS, text):
        return "claude_first"
    if labels & {"flutter-web", "ux"} or matches(UI_KEYWORDS, text):
        return "ui_validation"
    if labels & {"automation"} or matches(AUTOMATION_KEYWORDS, f"{text}\n{comments}"):
        return "automation_wbs"
    if matches(DATA_KEYWORDS, comments):
        return "data_or_security"
    return "scoped_implementation"


def split_recommendation(kind: str) -> str:
    if kind in {"data_or_security", "claude_first"}:
        return "multi_pr_or_claude_first"
    if kind == "blocked_or_manual":
        return "blocked_until_owner_decision"
    return "single_scoped_pr"


def write_set_for(kind: str) -> list[str]:
    write_sets = {
        "automation_wbs": [
            "scripts/",
            ".github/workflows/",
            "docs/automation/",
            "docs/WBS_2_INSTANCE_ROUTING.md",
        ],
        "ui_validation": [
            "lib/",
            "test/e2e/",
            "docs/",
        ],
        "data_or_security": [
            "docs/issue-fix-plans/ or docs/adr/ before implementation",
            "supabase/migrations/ only after Claude Code #1 design approval",
            "supabase/functions/ only after Claude Code #1 design approval",
        ],
        "claude_first": [
            "docs/architecture/",
            "docs/adr/",
            "docs/issue-fix-plans/",
        ],
        "blocked_or_manual": [
            "Issue comment only",
            "WBS owner/status note only",
        ],
        "scoped_implementation": [
            "Issue-specific files only",
            "tests for changed behavior",
            "docs for handoff evidence",
        ],
    }
    return write_sets[kind]


def next_owner_for(kind: str) -> str:
    if kind in {"automation_wbs", "ui_validation", "scoped_implementation"}:
        return "Codex #1"
    if kind == "blocked_or_manual":
        return "User/Automation"
    return "Claude Code #1"


def build_plan(issue: dict[str, Any]) -> dict[str, Any]:
    kind = task_kind(issue)
    latest = latest_comment(issue)
    due_date = parse_due_date(issue)
    return {
        "issue": issue.get("number"),
        "title": issue.get("title", ""),
        "url": issue.get("url", ""),
        "labels": sorted(label_names(issue.get("labels"))),
        "due_date": due_date,
        "kind": kind,
        "next_owner": next_owner_for(kind),
        "split": split_recommendation(kind),
        "active_flow": "Claude Code #1 + Codex #1 + GitHub Actions evidence",
        "retired_legacy_lanes": [
            "Codex #2",
            "Codex #3/#4",
            "VSCode/Win/PS lane expansion",
            "agent-in-agent execution",
        ],
        "roles": ROLE_TEMPLATES,
        "write_set": write_set_for(kind),
        "prohibited_write_set": [
            "unrelated dirty primary-worktree files",
            "secrets or local credentials",
            "Claude Code #1 worktrees owned by another task",
            "production deploy workflows without Claude Code #1 review",
            "database migrations without explicit design note",
        ],
        "conflict_rules": [
            "create a fresh task worktree from latest origin/main",
            "register or record planned paths before editing",
            "run worktree registry preflight for the planned or staged paths",
            "run instance conflict predictor when paths touch shared workflows, migrations, or cross-instance docs",
            "stop on High overlap and hand the packet to Claude Code #1",
        ],
        "validation": [
            "python script/unit tests for changed automation",
            "git diff --check HEAD~1..HEAD",
            "PR required checks green",
            "Deploy to Production green after merge",
        ],
        "evidence_targets": [
            "PR body Minimal E2E Gate section",
            "Issue closing comment or linked merged PR",
            "GitHub Actions run URL",
            "WBS status/progress note when the task is not auto-closed",
            "worktree/branch cleanup confirmation",
        ],
        "handoff_packet_fields": [
            "Issue/WBS id",
            "branch",
            "worktree",
            "allowed write set",
            "prohibited write set",
            "validation command",
            "unresolved risk",
            "next owner",
        ],
        "handoff_to_claude_when": [
            "risk is data_or_security or claude_first",
            "the task needs product/legal/business judgment",
            "the safe write set cannot be named before editing",
            "conflict predictor or worktree registry reports High",
        ],
        "resource_hygiene": [
            "record C drive free space before and after the task",
            "record top memory processes before and after the task",
            "avoid long-lived dev server, dart, node, and git leftovers",
            "remove task node_modules/cache outputs through worktree cleanup",
            "run git worktree prune and git gc --auto after merge cleanup",
        ],
        "latest_issue_comment": latest,
    }


def plan_sort_key(plan: dict[str, Any]) -> tuple[str, int]:
    due = plan.get("due_date") or "9999-12-31"
    number = int(plan.get("issue") or 0)
    return due, number


def run_gh_json(args: list[str]) -> Any:
    proc = subprocess.run(
        ["gh", *args],
        text=True,
        encoding="utf-8",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "gh command failed")
    text = proc.stdout.strip()
    return json.loads(text) if text else {}


def fetch_issue(repo: str, number: int) -> dict[str, Any]:
    return run_gh_json(
        [
            "issue",
            "view",
            str(number),
            "--repo",
            repo,
            "--comments",
            "--json",
            "number,title,body,labels,url,state,comments,updatedAt",
        ]
    )


def fetch_issue_queue(repo: str, query: str, limit: int) -> list[dict[str, Any]]:
    items = run_gh_json(
        [
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "open",
            "--limit",
            str(limit),
            "--search",
            query,
            "--json",
            "number",
        ]
    )
    return [fetch_issue(repo, int(item["number"])) for item in items]


def read_json(path: str | None, default: Any) -> Any:
    if not path:
        return default
    source = Path(path)
    if not source.exists():
        return default
    return json.loads(source.read_text(encoding="utf-8"))


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# WBS Role Harness Report",
        "",
        f"- Repository: `{report['repo']}`",
        f"- Generated: `{report['generated_at']}`",
        "- Active development lanes: Claude Code #1, Codex #1, GitHub Actions evidence, User/Automation decisions.",
        "- Legacy multi-agent lanes are treated as historical context, not current execution owners.",
        "",
    ]
    plans = report.get("plans", [])
    if not plans:
        lines.append("- No plans generated.")
        return "\n".join(lines) + "\n"

    for plan in plans:
        title = plan["title"]
        lines.extend(
            [
                f"## Issue #{plan['issue']} - {title}",
                "",
                f"- URL: {plan.get('url') or 'n/a'}",
                f"- Due date: `{plan.get('due_date') or 'unknown'}`",
                f"- Kind: `{plan['kind']}`",
                f"- Next owner: `{plan['next_owner']}`",
                f"- Split recommendation: `{plan['split']}`",
                "",
                "### Role Templates",
                "",
            ]
        )
        for role in plan["roles"]:
            lines.append(f"- `{role['role']}`: {role['owns']}")
        lines.extend(["", "### Write Set", ""])
        lines.extend(f"- `{item}`" for item in plan["write_set"])
        lines.extend(["", "### Prohibited Write Set", ""])
        lines.extend(f"- {item}" for item in plan["prohibited_write_set"])
        lines.extend(["", "### Conflict Rules", ""])
        lines.extend(f"- {item}" for item in plan["conflict_rules"])
        lines.extend(["", "### Validation", ""])
        lines.extend(f"- `{item}`" for item in plan["validation"])
        lines.extend(["", "### Evidence Targets", ""])
        lines.extend(f"- {item}" for item in plan["evidence_targets"])
        lines.extend(["", "### Handoff Packet Fields", ""])
        lines.extend(f"- {item}" for item in plan["handoff_packet_fields"])
        lines.extend(["", "### Handoff To Claude Code #1 When", ""])
        lines.extend(f"- {item}" for item in plan["handoff_to_claude_when"])
        lines.extend(["", "### Resource Hygiene", ""])
        lines.extend(f"- {item}" for item in plan["resource_hygiene"])
        latest = plan.get("latest_issue_comment")
        if latest:
            excerpt = " ".join(str(latest.get("body", "")).split())[:280]
            lines.extend(
                [
                    "",
                    "### Latest Issue Comment",
                    "",
                    f"- Created: `{latest.get('created_at') or 'unknown'}`",
                    f"- URL: {latest.get('url') or 'n/a'}",
                    f"- Excerpt: {excerpt}",
                ]
            )
        lines.append("")
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--issue-number", type=int)
    parser.add_argument("--issues-json", help="Offline Issue JSON fixture.")
    parser.add_argument("--max-issues", type=int, default=10)
    parser.add_argument(
        "--query",
        default="label:priority:high label:wbs",
        help="Issue search query used when --issue-number and --issues-json are omitted.",
    )
    parser.add_argument("--output-md", default="/tmp/wbs-role-harness.md")
    parser.add_argument("--output-json", default="/tmp/wbs-role-harness.json")
    return parser.parse_args(argv)


def issues_from_args(args: argparse.Namespace) -> list[dict[str, Any]]:
    if args.issues_json:
        issues = read_json(args.issues_json, [])
        if not isinstance(issues, list):
            raise SystemExit("--issues-json must contain a JSON list")
        return issues
    if args.issue_number:
        return [fetch_issue(args.repo, args.issue_number)]
    return fetch_issue_queue(args.repo, args.query, args.max_issues)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    issues = issues_from_args(args)
    plans = sorted((build_plan(issue) for issue in issues), key=plan_sort_key)
    report = {
        "repo": args.repo,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "query": None if args.issue_number or args.issues_json else args.query,
        "plans": plans,
    }
    output_json = Path(args.output_json)
    output_md = Path(args.output_md)
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_md.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    output_md.write_text(render_markdown(report), encoding="utf-8")
    print(
        json.dumps(
            {
                "plans": len(plans),
                "owners": sorted({plan["next_owner"] for plan in plans}),
                "splits": sorted({plan["split"] for plan in plans}),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
