#!/usr/bin/env python3
"""Parse memory/project_*.md ## 次回 candidate sections and emit GitHub Issues for new items.

Win版#132 part 118 (2026-05-03) — Issue #1647 受け入れ条件 #3 完全自動化.

Reads each memory/project_YYYYMMDD_*.md (default last 7 days), extracts the
"## 次回 candidate" section, dedups against open issues with label `追加要望`,
and prints either a Markdown plan or executes `gh issue create` per item.

Design notes:
- Dependency-free (stdlib only). gh CLI is invoked via subprocess only when --apply.
- Default mode is dry-run. Pass --apply to actually create issues.
- Idempotent via title prefix dedup (= same title open issue → skip).
- Filters out lines that are pure issue references (e.g. "#1700-1707 8 件" already linked).
- Designed to run from `.github/workflows/session-residuals-sync.yml` daily.

Usage:
    python scripts/session_residuals_to_issue.py                    # dry-run last 7d
    python scripts/session_residuals_to_issue.py --days 14          # last 14 days
    python scripts/session_residuals_to_issue.py --apply            # actually create issues
    python scripts/session_residuals_to_issue.py --memory-dir <p>   # override memory dir
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


# ──────────────────────────────────────────────────────────────────────
# Defaults
# ──────────────────────────────────────────────────────────────────────

DEFAULT_MEMORY_DIRS = [
    # Win版 (= primary location for this script)
    Path.home() / ".claude" / "projects" / "C--Users-kanta-GitHub-my-web-app" / "memory",
    # Repo-local memory/ (= some instances commit memos here)
    Path("memory"),
]

CANDIDATE_HEADER = re.compile(
    r"^##\s+(次回\s*candidate|次回タスク候補|次回\s*candidates?|次回アクション候補)",
    re.IGNORECASE,
)
NEXT_SECTION = re.compile(r"^##\s+\S")
ISSUE_REF_LINE = re.compile(r"^[\s\-\*\d\.]*\[?#\d{3,5}")
HASH_PREFIX = re.compile(r"^[\s\-\*\d\.\)]*")


@dataclass(frozen=True)
class Candidate:
    source: Path
    line_no: int
    text: str
    short_id: str  # truncated for dedup checks


@dataclass
class RunReport:
    sources: int = 0
    candidates: int = 0
    skipped_dup: int = 0
    skipped_link_only: int = 0
    skipped_existing_issue: int = 0
    created: int = 0
    titles: list[str] = field(default_factory=list)


# ──────────────────────────────────────────────────────────────────────
# IO helpers
# ──────────────────────────────────────────────────────────────────────

def list_memory_files(directories: Iterable[Path], days: int) -> list[Path]:
    """Find memory/project_YYYYMMDD_*.md files within last N days."""
    cutoff = dt.date.today() - dt.timedelta(days=days)
    found: list[Path] = []
    for d in directories:
        if not d.exists():
            continue
        for p in d.glob("project_*.md"):
            m = re.match(r"project_(\d{8})_", p.name)
            if not m:
                continue
            try:
                d_date = dt.datetime.strptime(m.group(1), "%Y%m%d").date()
            except ValueError:
                continue
            if d_date >= cutoff:
                found.append(p)
    return sorted(found)


def parse_candidates(path: Path) -> list[Candidate]:
    """Extract `## 次回 candidate` block lines from a memo file."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return []
    lines = text.splitlines()
    in_section = False
    out: list[Candidate] = []
    for idx, raw in enumerate(lines, start=1):
        if CANDIDATE_HEADER.match(raw):
            in_section = True
            continue
        if in_section and NEXT_SECTION.match(raw):
            break
        if not in_section:
            continue
        line = raw.strip()
        if not line or line.startswith(("#", "<!--", "```")):
            continue
        # require a list bullet OR numbered start
        if not re.match(r"^[-*]\s|^\d+\.\s", line):
            continue
        cleaned = HASH_PREFIX.sub("", line).strip()
        if not cleaned:
            continue
        # Skip narrative / meta lines after bullet strip
        if cleaned.startswith(("既存:", "残:", "残 WBS:", "§", "(", "→", "なお", "※")):
            continue
        short = cleaned[:80]
        out.append(Candidate(source=path, line_no=idx, text=cleaned, short_id=short))
    return out


# ──────────────────────────────────────────────────────────────────────
# Dedup
# ──────────────────────────────────────────────────────────────────────

def gh_open_issue_titles(label: str = "追加要望") -> set[str]:
    """Fetch open issue titles with given label via gh CLI. Returns empty set on error."""
    try:
        result = subprocess.run(
            [
                "gh", "issue", "list",
                "--label", label,
                "--state", "open",
                "--limit", "200",
                "--json", "title",
            ],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        data = json.loads(result.stdout or "[]")
        return {row["title"] for row in data if "title" in row}
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired,
            json.JSONDecodeError):
        return set()


def is_link_only(text: str) -> bool:
    """Return True if the text is essentially just an issue reference (no actionable content)."""
    if ISSUE_REF_LINE.match(text):
        # if line is mostly issue refs (e.g. "#1700-1707 8 件 (NotebookLM cross-check ...)")
        # and contains no verb, treat as link-only.
        verbs = ("実装", "整備", "追加", "化", "完成", "対応", "整理",
                 "検討", "起票", "登録", "作成", "削除", "改善", "確認")
        return not any(v in text for v in verbs)
    return False


def title_already_exists(title: str, existing: set[str]) -> bool:
    if title in existing:
        return True
    # Loose match: same first 50 chars
    head = title[:50]
    return any(t.startswith(head) for t in existing)


# ──────────────────────────────────────────────────────────────────────
# Issue rendering
# ──────────────────────────────────────────────────────────────────────

ISSUE_TITLE_PREFIX = "[追加要望][session-residual]"


def render_title(cand: Candidate) -> str:
    """Build a deterministic, dedupable issue title."""
    short = cand.text.split("(")[0].split(" — ")[0].split(" / ")[0].strip()
    short = re.sub(r"\[[^\]]+\]", "", short).strip()
    short = short[:80]
    return f"{ISSUE_TITLE_PREFIX} {short}"


def render_body(cand: Candidate) -> str:
    rel = cand.source.name
    return (
        "## 自動抽出された session 残作業\n\n"
        f"- **元ファイル**: `{rel}` (line {cand.line_no})\n"
        f"- **行内容**:\n\n  > {cand.text}\n\n"
        "## 背景\n\n"
        "Win版#132 part 118 で実装された `scripts/session_residuals_to_issue.py` が、\n"
        "memory/project_*.md の `## 次回 candidate` section から actionable item を抽出し、\n"
        "後続 session で拾えるよう自動 Issue 化したもの (= Issue [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647) 受け入れ条件 #3).\n\n"
        "## 推奨対応\n\n"
        "1. 内容を確認し、担当 instance を判断 (Win/VSCode/PS/Codex/User)\n"
        "2. 不要なら close + reason コメント\n"
        "3. 実施するなら適切な label (priority / 領域) を追加 + assign\n\n"
        "## 関連\n\n"
        "- workflow: `.github/workflows/session-residuals-sync.yml`\n"
        "- script: `scripts/session_residuals_to_issue.py`\n"
        "- 設計: `docs/CODEX_MEMORY_AUTOMATIONS.md` §5\n"
        "- WBS task: [#1647](https://github.com/kanta13jp1/my_web_app/issues/1647)\n"
        "\n(auto-opened by session-residuals-sync.yml)\n"
    )


def create_issue(title: str, body: str, label: str) -> bool:
    try:
        subprocess.run(
            [
                "gh", "issue", "create",
                "--title", title,
                "--label", label,
                "--body", body,
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )
        return True
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) as exc:
        print(f"[error] gh issue create failed: {exc}", file=sys.stderr)
        return False


# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--memory-dir", action="append", type=Path,
                    help="Override memory directory (repeatable). Default = ~/.claude/projects/.../memory + ./memory")
    ap.add_argument("--days", type=int, default=7, help="How many days back to scan (default 7)")
    ap.add_argument("--apply", action="store_true",
                    help="Actually create GitHub Issues (default: dry-run / print plan only)")
    ap.add_argument("--label", default="追加要望,automation,session-residual",
                    help="Comma-separated labels for created issues")
    ap.add_argument("--limit", type=int, default=10,
                    help="Max issues to create per run (safety cap)")
    args = ap.parse_args()

    dirs = args.memory_dir or DEFAULT_MEMORY_DIRS
    files = list_memory_files(dirs, args.days)
    report = RunReport(sources=len(files))

    seen_titles: set[str] = set()
    existing_titles = gh_open_issue_titles() if args.apply else set()

    print(f"[scan] {report.sources} memo file(s) within last {args.days}d")

    for path in files:
        cands = parse_candidates(path)
        report.candidates += len(cands)
        for cand in cands:
            title = render_title(cand)
            if title in seen_titles:
                report.skipped_dup += 1
                continue
            seen_titles.add(title)

            if is_link_only(cand.text):
                report.skipped_link_only += 1
                continue

            if title_already_exists(title, existing_titles):
                report.skipped_existing_issue += 1
                continue

            if report.created >= args.limit:
                print(f"[cap] stop at --limit {args.limit}")
                break

            if args.apply:
                ok = create_issue(title, render_body(cand), args.label)
                if ok:
                    report.created += 1
                    report.titles.append(title)
                    print(f"[create] {title}")
            else:
                report.created += 1
                report.titles.append(title)
                print(f"[plan] {title}\n         from {path.name}:{cand.line_no} → {cand.text[:120]}")
        if report.created >= args.limit:
            break

    summary = {
        "mode": "apply" if args.apply else "dry-run",
        "sources": report.sources,
        "candidates_total": report.candidates,
        "skipped_dup_in_run": report.skipped_dup,
        "skipped_link_only": report.skipped_link_only,
        "skipped_existing_open_issue": report.skipped_existing_issue,
        "created_or_planned": report.created,
        "limit": args.limit,
    }
    print()
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
