#!/usr/bin/env python3
"""Cross-check NotebookLM list against GitHub Issues.

Win版#132 part 120 (2026-05-03) — manual triage (= part 115/117/119) automation.

Reads `notebooklm list --json`, then for each notebook ID searches open + closed
GitHub Issues for the 8-char ID prefix (= human convention used in past Issues).
Outputs a per-notebook report:
- notebook ID + title
- open Issue count + numbers
- closed Issue count
- gap classification (= TRUE_GAP / DUP_OPEN / OK)

Two failure modes the script highlights for fleet hygiene:
1. **TRUE_GAP**: notebook exists but no Issue references it → manual triage required
2. **DUP_OPEN**: notebook has 2+ open Issues → cleanup candidate (= dedup by close)

Usage:
    PYTHONUTF8=1 python scripts/notebooklm_issue_crosscheck.py             # text report
    PYTHONUTF8=1 python scripts/notebooklm_issue_crosscheck.py --json      # JSON
    PYTHONUTF8=1 python scripts/notebooklm_issue_crosscheck.py --gaps-only # show TRUE_GAP only
    PYTHONUTF8=1 python scripts/notebooklm_issue_crosscheck.py --dup-only  # show DUP_OPEN only
    PYTHONUTF8=1 python scripts/notebooklm_issue_crosscheck.py --comment-on-issue 1647

Dependency-free (stdlib only / gh + notebooklm CLI 経由 subprocess).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from typing import Any


@dataclass
class IssueRef:
    number: int
    state: str  # OPEN / CLOSED
    title: str


@dataclass
class NotebookCheck:
    id: str
    short_id: str
    title: str
    open_issues: list[IssueRef] = field(default_factory=list)
    closed_issues: list[IssueRef] = field(default_factory=list)
    classification: str = "OK"  # TRUE_GAP / DUP_OPEN / OK


# ──────────────────────────────────────────────────────────────────────
# IO helpers
# ──────────────────────────────────────────────────────────────────────

def fetch_notebooklm_list() -> list[dict[str, Any]]:
    """Run notebooklm list --json and return notebooks list."""
    try:
        result = subprocess.run(
            ["notebooklm", "list", "--json"],
            capture_output=True,
            text=True,
            check=True,
            timeout=60,
            env={**os.environ, "PYTHONUTF8": "1"},
        )
        data = json.loads(result.stdout or "{}")
        return data.get("notebooks", [])
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired,
            json.JSONDecodeError) as exc:
        print(f"[error] notebooklm list failed: {exc}", file=sys.stderr)
        return []


def search_issues_for_id(short_id: str, state: str = "all") -> list[IssueRef]:
    """Search GH issues whose title contains the 8-char notebook ID."""
    try:
        result = subprocess.run(
            [
                "gh", "issue", "list",
                "--search", f"{short_id} in:title",
                "--state", state,
                "--limit", "50",
                "--json", "number,state,title",
            ],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        rows = json.loads(result.stdout or "[]")
        return [
            IssueRef(number=int(r["number"]), state=r["state"], title=r["title"])
            for r in rows
            if short_id in r.get("title", "")
        ]
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired,
            json.JSONDecodeError):
        return []


def classify(check: NotebookCheck) -> str:
    if not check.open_issues and not check.closed_issues:
        return "TRUE_GAP"
    if len(check.open_issues) >= 2:
        return "DUP_OPEN"
    return "OK"


# ──────────────────────────────────────────────────────────────────────
# Reporting
# ──────────────────────────────────────────────────────────────────────

def render_text(checks: list[NotebookCheck]) -> str:
    lines = []
    by_class: dict[str, list[NotebookCheck]] = {"TRUE_GAP": [], "DUP_OPEN": [], "OK": []}
    for c in checks:
        by_class[c.classification].append(c)

    lines.append(f"Total notebooks: {len(checks)}")
    lines.append(f"  TRUE_GAP (no Issue):  {len(by_class['TRUE_GAP'])}")
    lines.append(f"  DUP_OPEN (2+ open):   {len(by_class['DUP_OPEN'])}")
    lines.append(f"  OK (1 open or closed): {len(by_class['OK'])}")
    lines.append("")

    if by_class["TRUE_GAP"]:
        lines.append("## TRUE_GAP — no Issue exists yet")
        for c in by_class["TRUE_GAP"]:
            lines.append(f"- `{c.short_id}` {c.title[:70]}")
        lines.append("")

    if by_class["DUP_OPEN"]:
        lines.append("## DUP_OPEN — multiple open Issues (cleanup candidate)")
        for c in by_class["DUP_OPEN"]:
            issues = ", ".join(f"#{i.number}" for i in c.open_issues)
            lines.append(f"- `{c.short_id}` {c.title[:60]} → open: {issues}")
        lines.append("")

    return "\n".join(lines)


def render_json(checks: list[NotebookCheck]) -> str:
    out = {
        "total": len(checks),
        "true_gap": [asdict(c) for c in checks if c.classification == "TRUE_GAP"],
        "dup_open": [asdict(c) for c in checks if c.classification == "DUP_OPEN"],
        "ok_count": sum(1 for c in checks if c.classification == "OK"),
    }
    return json.dumps(out, ensure_ascii=False, indent=2)


def comment_to_issue(issue_number: int, body: str) -> bool:
    try:
        subprocess.run(
            ["gh", "issue", "comment", str(issue_number), "--body", body],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) as exc:
        print(f"[error] gh issue comment failed: {exc}", file=sys.stderr)
        return False


# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true", help="JSON output instead of text")
    ap.add_argument("--gaps-only", action="store_true", help="Show only TRUE_GAP entries")
    ap.add_argument("--dup-only", action="store_true", help="Show only DUP_OPEN entries")
    ap.add_argument("--comment-on-issue", type=int, default=0,
                    help="Post summary as comment to given Issue number")
    ap.add_argument("--json-out", default="",
                    help="Write the full machine-readable report to this path")
    ap.add_argument("--limit", type=int, default=200,
                    help="Max notebooks to process (safety cap)")
    args = ap.parse_args()

    notebooks = fetch_notebooklm_list()
    if not notebooks:
        print("[warn] No notebooks fetched (check notebooklm CLI auth)", file=sys.stderr)
        return 1

    notebooks = notebooks[: args.limit]
    print(f"[scan] {len(notebooks)} notebooks", file=sys.stderr)

    checks: list[NotebookCheck] = []
    for nb in notebooks:
        nid = str(nb.get("id", ""))
        if not nid:
            continue
        short = nid[:8]
        title = str(nb.get("title", "")).strip()
        check = NotebookCheck(id=nid, short_id=short, title=title)
        all_issues = search_issues_for_id(short, state="all")
        for issue in all_issues:
            if issue.state == "OPEN":
                check.open_issues.append(issue)
            else:
                check.closed_issues.append(issue)
        check.classification = classify(check)
        checks.append(check)

    # Filter
    if args.gaps_only:
        checks = [c for c in checks if c.classification == "TRUE_GAP"]
    elif args.dup_only:
        checks = [c for c in checks if c.classification == "DUP_OPEN"]

    if args.json:
        report = render_json(checks)
    else:
        report = render_text(checks)
    print(report)

    if args.json_out:
        with open(args.json_out, "w", encoding="utf-8", newline="\n") as f:
            f.write(render_json(checks))
            f.write("\n")

    if args.comment_on_issue:
        body = (
            f"🔍 NotebookLM × Issue cross-check (auto)\n\n"
            f"```\n{report[:5000]}\n```\n\n"
            f"script: `scripts/notebooklm_issue_crosscheck.py` "
            f"(= Win版#132 part 120 / [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) follow-up)\n"
        )
        ok = comment_to_issue(args.comment_on_issue, body)
        if ok:
            print(f"[comment] posted to #{args.comment_on_issue}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
