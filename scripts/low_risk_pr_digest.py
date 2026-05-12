#!/usr/bin/env python3
"""Classify low-risk PR/Issue candidates without approving or merging them."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


MAX_LOW_RISK_FILES = 12
MAX_LOW_RISK_CHURN = 600

LOW_RISK_LABELS = {
    "documentation",
    "docs",
    "dependencies",
    "dependabot",
    "automation",
    "wbs",
}

HIGH_RISK_LABELS = {
    "security",
    "supabase",
    "edge-function",
    "mobile",
    "workflow-failure",
    "priority:critical",
}

LOW_RISK_PATH_PATTERNS = (
    r"^docs/",
    r"^test/",
    r"^scripts/[^/]+_test\.py$",
    r"^scripts/check_[^/]+\.py$",
    r"^scripts/.*_gate(_test)?\.py$",
    r"^\.github/workflows/(minimal-e2e-gate|pr-review-routing|wbs-[^/]+|issue-[^/]+)\.yml$",
    r"^\.github/dependabot\.yml$",
    r"^package(-lock)?\.json$",
    r"^requirements\.txt$",
)

HIGH_RISK_PATH_PATTERNS = (
    r"^supabase/migrations/",
    r"^supabase/functions/",
    r"^lib/(auth|billing|payments|subscription|firebase|supabase)/",
    r"^\.github/workflows/(deploy|.*deploy.*|ci-auto-fix|claude-agent-review).*\.yml$",
    r"^firebase\.json$",
    r"^firestore\.",
    r"^storage\.",
    r"(^|/)\.env",
    r"secret",
    r"credential",
    r"service[_-]?role",
    r"rls",
)

HIGH_RISK_TEXT_PATTERNS = (
    r"\bsecret\b",
    r"\bcredential\b",
    r"\btoken\b",
    r"\bauth\b",
    r"\bpayment\b",
    r"\bbilling\b",
    r"\bstripe\b",
    r"\bsubscription\b",
    r"\bproduction\b",
    r"\bdeploy\b",
    r"\bmigration\b",
    r"\brls\b",
    r"\bservice[_ -]?role\b",
    r"\blegal\b",
    r"\btax\b",
)


def norm_path(path: str) -> str:
    return path.replace("\\", "/").lstrip("./")


def matches_any(patterns: tuple[str, ...], value: str) -> bool:
    return any(re.search(pattern, value, flags=re.IGNORECASE) for pattern in patterns)


def label_names(raw_labels: list[dict[str, Any]] | list[str] | None) -> set[str]:
    names: set[str] = set()
    for label in raw_labels or []:
        if isinstance(label, str):
            names.add(label.lower())
        elif isinstance(label, dict):
            name = label.get("name")
            if isinstance(name, str):
                names.add(name.lower())
    return names


def file_paths(files: list[dict[str, Any]] | list[str] | None) -> list[str]:
    paths: list[str] = []
    for item in files or []:
        if isinstance(item, str):
            paths.append(norm_path(item))
        elif isinstance(item, dict):
            path = item.get("path") or item.get("filename")
            if isinstance(path, str):
                paths.append(norm_path(path))
    return paths


def file_churn(files: list[dict[str, Any]] | None, additions: int = 0, deletions: int = 0) -> int:
    churn = 0
    for item in files or []:
        if not isinstance(item, dict):
            continue
        churn += int(item.get("additions") or 0) + int(item.get("deletions") or 0)
    return churn if churn else additions + deletions


def classify_paths(paths: list[str]) -> tuple[str, list[str], list[str]]:
    stop_reasons: list[str] = []
    evidence: list[str] = []
    if not paths:
        return "medium", ["No changed files were available for classification."], evidence
    if len(paths) > MAX_LOW_RISK_FILES:
        stop_reasons.append(f"Changed file count {len(paths)} exceeds {MAX_LOW_RISK_FILES}.")

    unknown_paths: list[str] = []
    for path in paths:
        if matches_any(HIGH_RISK_PATH_PATTERNS, path):
            stop_reasons.append(f"High-risk path: {path}")
        elif matches_any(LOW_RISK_PATH_PATTERNS, path):
            evidence.append(f"Low-risk path: {path}")
        else:
            unknown_paths.append(path)

    if unknown_paths:
        stop_reasons.append("Unclassified paths require manual review: " + ", ".join(unknown_paths[:8]))

    return ("low" if not stop_reasons else "high"), stop_reasons, evidence


def classify_pr(pr: dict[str, Any]) -> dict[str, Any]:
    labels = label_names(pr.get("labels"))
    paths = file_paths(pr.get("files"))
    churn = file_churn(
        pr.get("files") if isinstance(pr.get("files"), list) else [],
        int(pr.get("additions") or 0),
        int(pr.get("deletions") or 0),
    )
    risk, stop_reasons, evidence = classify_paths(paths)
    text = f"{pr.get('title', '')}\n{pr.get('body', '')}"

    if labels & HIGH_RISK_LABELS:
        stop_reasons.append("High-risk labels: " + ", ".join(sorted(labels & HIGH_RISK_LABELS)))
    if matches_any(HIGH_RISK_TEXT_PATTERNS, text):
        stop_reasons.append("Title/body contains high-risk keywords.")
    if churn > MAX_LOW_RISK_CHURN:
        stop_reasons.append(f"Churn {churn} exceeds {MAX_LOW_RISK_CHURN}.")
    if pr.get("isDraft"):
        stop_reasons.append("Draft PRs are not autonomous-review candidates.")

    low_label_evidence = sorted(labels & LOW_RISK_LABELS)
    if low_label_evidence:
        evidence.append("Low-risk labels: " + ", ".join(low_label_evidence))

    final_risk = "low" if risk == "low" and not stop_reasons else "high"
    return {
        "kind": "pull_request",
        "number": pr.get("number"),
        "title": pr.get("title", ""),
        "url": pr.get("url", ""),
        "risk": final_risk,
        "candidate": final_risk == "low",
        "changed_files": paths,
        "churn": churn,
        "evidence": evidence,
        "stop_reasons": stop_reasons,
        "required_checks": [
            "CI / Lint, Format, and Test",
            "Security Check",
            "Minimal E2E Gate",
            "AI Agent Code Review",
        ],
        "allowed_action": "comment_only_autonomous_review",
        "merge_policy": "human_approval_required",
    }


def classify_issue(issue: dict[str, Any]) -> dict[str, Any]:
    labels = label_names(issue.get("labels"))
    text = f"{issue.get('title', '')}\n{issue.get('body', '')}"
    stop_reasons: list[str] = []
    evidence: list[str] = []
    if labels & HIGH_RISK_LABELS:
        stop_reasons.append("High-risk labels: " + ", ".join(sorted(labels & HIGH_RISK_LABELS)))
    if matches_any(HIGH_RISK_TEXT_PATTERNS, text):
        stop_reasons.append("Title/body contains high-risk keywords.")
    if labels & LOW_RISK_LABELS:
        evidence.append("Low-risk labels: " + ", ".join(sorted(labels & LOW_RISK_LABELS)))
    else:
        stop_reasons.append("No low-risk routing label is present.")
    return {
        "kind": "issue",
        "number": issue.get("number"),
        "title": issue.get("title", ""),
        "url": issue.get("url", ""),
        "risk": "low" if not stop_reasons else "high",
        "candidate": not stop_reasons,
        "evidence": evidence,
        "stop_reasons": stop_reasons,
        "allowed_action": "open_scoped_pr_with_evidence",
        "merge_policy": "human_approval_required",
    }


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


def fetch_pr(repo: str, number: int) -> dict[str, Any]:
    return run_gh_json(
        [
            "pr",
            "view",
            str(number),
            "--repo",
            repo,
            "--json",
            "number,title,body,url,labels,files,additions,deletions,isDraft,headRefName",
        ]
    )


def fetch_open_prs(repo: str, limit: int) -> list[dict[str, Any]]:
    items = run_gh_json(
        [
            "pr",
            "list",
            "--repo",
            repo,
            "--state",
            "open",
            "--limit",
            str(limit),
            "--json",
            "number",
        ]
    )
    return [fetch_pr(repo, int(item["number"])) for item in items]


def fetch_open_issues(repo: str, limit: int) -> list[dict[str, Any]]:
    return run_gh_json(
        [
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "open",
            "--limit",
            str(limit),
            "--json",
            "number,title,body,url,labels",
        ]
    )


def read_json(path: str | None, default: Any) -> Any:
    if not path:
        return default
    source = Path(path)
    if not source.exists():
        return default
    return json.loads(source.read_text(encoding="utf-8"))


def render_markdown(report: dict[str, Any]) -> str:
    lines = [
        "# Low-Risk PR Digestion Report",
        "",
        f"- Repository: `{report['repo']}`",
        f"- Generated: `{report['generated_at']}`",
        f"- Mode: `{report['mode']}`",
        "- Autonomous action: comment/report only; never approve, merge, or push to protected branches.",
        "",
        "## Pull Requests",
        "",
    ]
    pr_items = report.get("pull_requests", [])
    if not pr_items:
        lines.append("- None inspected.")
    for item in pr_items:
        mark = "candidate" if item["candidate"] else "blocked"
        lines.append(f"- PR #{item['number']} {mark}: {item['title']}")
        lines.append(f"  - Risk: `{item['risk']}`")
        lines.append(f"  - Merge policy: `{item['merge_policy']}`")
        if item.get("changed_files"):
            lines.append("  - Scope: " + ", ".join(f"`{path}`" for path in item["changed_files"][:10]))
        if item["evidence"]:
            lines.append("  - Evidence: " + " / ".join(item["evidence"][:4]))
        if item["stop_reasons"]:
            lines.append("  - Stop reasons: " + " / ".join(item["stop_reasons"][:4]))
        lines.append("  - Required checks: " + ", ".join(f"`{check}`" for check in item["required_checks"]))

    lines.extend(["", "## Issues", ""])
    issue_items = report.get("issues", [])
    if not issue_items:
        lines.append("- None inspected.")
    for item in issue_items:
        mark = "candidate" if item["candidate"] else "blocked"
        lines.append(f"- Issue #{item['number']} {mark}: {item['title']}")
        lines.append(f"  - Risk: `{item['risk']}`")
        if item["evidence"]:
            lines.append("  - Evidence: " + " / ".join(item["evidence"][:4]))
        if item["stop_reasons"]:
            lines.append("  - Stop reasons: " + " / ".join(item["stop_reasons"][:4]))

    lines.extend(
        [
            "",
            "## Stop Conditions",
            "",
            "- Any secret, auth, payment, billing, RLS, service_role, migration, Supabase function, production deploy, legal, or tax signal stops autonomous digestion.",
            "- Draft PRs, unclassified file paths, large churn, or more than 12 changed files require Claude Code #1 or user routing.",
            "- Candidate PRs may receive an autonomous comment with evidence, but human approval remains required before merge.",
        ]
    )
    return "\n".join(lines) + "\n"


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True)
    parser.add_argument("--pr-number", type=int)
    parser.add_argument("--max-prs", type=int, default=20)
    parser.add_argument("--max-issues", type=int, default=20)
    parser.add_argument("--prs-json", help="Offline PR JSON fixture.")
    parser.add_argument("--issues-json", help="Offline Issue JSON fixture.")
    parser.add_argument("--output-md", default="/tmp/low-risk-pr-digest.md")
    parser.add_argument("--output-json", default="/tmp/low-risk-pr-digest.json")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.prs_json:
        prs = read_json(args.prs_json, [])
    elif args.pr_number:
        prs = [fetch_pr(args.repo, args.pr_number)]
    else:
        prs = fetch_open_prs(args.repo, args.max_prs)

    issues = read_json(args.issues_json, None)
    if issues is None:
        issues = [] if args.pr_number else fetch_open_issues(args.repo, args.max_issues)

    report = {
        "repo": args.repo,
        "generated_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "mode": "single-pr" if args.pr_number else "queue",
        "pull_requests": [classify_pr(item) for item in prs],
        "issues": [classify_issue(item) for item in issues],
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
                "pull_requests": len(report["pull_requests"]),
                "pr_candidates": sum(1 for item in report["pull_requests"] if item["candidate"]),
                "issues": len(report["issues"]),
                "issue_candidates": sum(1 for item in report["issues"] if item["candidate"]),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
