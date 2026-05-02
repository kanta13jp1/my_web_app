#!/usr/bin/env python3
"""Route AI Tool Watch findings into GitHub issues and handoff drafts.

This is the deterministic bridge for the daily official-source watch:

1. Read docs/ai-tool-watch/latest-report.json.
2. If official sources changed and at least one high-priority routing group is
   active, create one deduplicated GitHub issue.
3. Write a cross-instance handoff draft that can be committed with the report.

The WBS handoff is intentionally issue-first. The existing issue-to-WBS
workflow can mirror the created issue into Supabase WBS without this script
needing service-role credentials.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LABELS = ["ai-tool-watch", "ai-tool-update", "追加要望"]
LABEL_COLORS = {
    "ai-tool-watch": "0E8A16",
    "ai-tool-update": "00897B",
    "追加要望": "EDEDED",
}
LABEL_DESCRIPTIONS = {
    "ai-tool-watch": "Official Claude Code and Codex source watch routing",
    "ai-tool-update": "AI tool Claude Code / Codex update adoption",
    "追加要望": "Feature or workflow request",
}


def repo_path(path: str) -> Path:
    p = Path(path)
    return p if p.is_absolute() else REPO_ROOT / p


def load_report(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def run_gh(args: list[str], repo: str) -> tuple[int, str, str]:
    cmd = ["gh", *args]
    if "--repo" not in args:
        cmd.extend(["--repo", repo])
    try:
        result = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except FileNotFoundError:
        return 127, "", "gh CLI not available"
    return result.returncode, result.stdout, result.stderr


def ensure_label(repo: str, label: str, dry_run: bool) -> None:
    if dry_run:
        return
    code, out, _ = run_gh(["label", "list", "--limit", "500", "--json", "name"], repo)
    if code != 0:
        print(f"WARN: cannot list labels; continuing without creating {label}", file=sys.stderr)
        return
    try:
        labels = {item.get("name", "") for item in json.loads(out)}
    except json.JSONDecodeError:
        labels = set()
    if label in labels:
        return
    color = LABEL_COLORS.get(label, "00897B")
    description = LABEL_DESCRIPTIONS.get(label, "AI tool watch routing")
    code, _, err = run_gh(
        [
            "label",
            "create",
            label,
            "--color",
            color,
            "--description",
            description,
        ],
        repo,
    )
    if code != 0:
        print(f"WARN: label create failed for {label}: {err.strip()}", file=sys.stderr)


def existing_issue_titles(repo: str, dry_run: bool) -> set[str]:
    if dry_run:
        return set()
    code, out, err = run_gh(
        ["issue", "list", "--state", "all", "--limit", "500", "--json", "title"],
        repo,
    )
    if code != 0:
        print(f"WARN: issue list failed; dedup disabled: {err.strip()}", file=sys.stderr)
        return set()
    try:
        return {item.get("title", "") for item in json.loads(out)}
    except json.JSONDecodeError:
        return set()


def compact_slug(value: str) -> str:
    lowered = value.lower()
    lowered = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return lowered or "source"


def changed_source_names(report: dict[str, Any]) -> list[str]:
    return [str(item.get("name", item.get("slug", "source"))) for item in report.get("changed_sources", [])]


def build_issue_title(report: dict[str, Any]) -> str:
    checked_at = str(report.get("checked_at", "unknown"))
    date = checked_at[:10] if len(checked_at) >= 10 else dt.date.today().isoformat()
    names = changed_source_names(report)
    if not names:
        names = ["official sources"]
    source_text = ", ".join(names[:3])
    if len(names) > 3:
        source_text += f", +{len(names) - 3}"
    title = f"[ai-tool-watch] {date} official AI tool changes: {source_text}"
    return title[:180]


def route_owner(groups: list[str]) -> str:
    if "hooks" in groups:
        return "Claude Code"
    if "schedule" in groups:
        return "Codex #2 / GitHub Actions"
    if "codex-runtime" in groups:
        return "Codex #1 / Codex #2"
    if "integration" in groups:
        return "Codex #2"
    if "quality-cost" in groups:
        return "Claude Code + Codex"
    return "Claude Code"


def route_instance(groups: list[str]) -> str:
    if "schedule" in groups:
        return "gha"
    if "codex-runtime" in groups or "integration" in groups:
        return "codex"
    return "win"


def render_issue_body(report: dict[str, Any]) -> str:
    checked_at = report.get("checked_at", "unknown")
    groups = [str(group) for group in report.get("high_priority_groups", [])]
    if not groups:
        groups = [str(group) for group in report.get("active_groups", [])]
    owner = route_owner(groups)
    instance = route_instance(groups)

    lines: list[str] = [
        "## Summary",
        "",
        "AI Tool Watch detected official Claude Code / Codex source changes that need repo routing.",
        "",
        f"- Checked at: `{checked_at}`",
        f"- Routing groups: `{', '.join(groups) if groups else 'none'}`",
        f"- Proposed owner: `{owner}`",
        f"- Proposed WBS instance: `{instance}`",
        "",
        "## Changed Sources",
        "",
    ]
    for item in report.get("changed_sources", []):
        lines.append(f"- **{item.get('name', item.get('slug', 'source'))}**")
        lines.append(f"  - URL: {item.get('url', '')}")
        lines.append(f"  - Latest signal: `{item.get('latest_signal', 'unknown')}`")
        item_groups = ", ".join((item.get("keyword_groups") or {}).keys()) or "none"
        lines.append(f"  - Keyword groups: `{item_groups}`")

    lines.extend(["", "## Recommended Actions", ""])
    routes = report.get("impact_routes", {})
    if routes:
        for group, route in routes.items():
            issues = ", ".join(route.get("issues", []))
            lines.append(f"- **{group}** ({issues}): {route.get('action', '')}")
    else:
        lines.append("- No deterministic route was found; inspect the report manually.")

    lines.extend(
        [
            "",
            "## WBS Route",
            "",
            "- category: `automation`",
            f"- instance: `{instance}`",
            f"- owner: `{owner}`",
            "- source: `scripts/ai_tool_watch.py`",
            "- expected sync: existing issue-to-WBS workflow should mirror this issue into `wbs_tasks`.",
            "",
            "## Acceptance Criteria",
            "",
            "- [ ] Decide KEEP/CLOSE for each changed official signal.",
            "- [ ] Route KEEP items to an implementation issue, hook, workflow check, or PR draft.",
            "- [ ] Close this issue if the change is a bug fix or already covered by existing automation.",
            "- [ ] Confirm WBS has a matching task or explicit no-op record.",
            "",
            "## Source Report",
            "",
            "- `docs/ai-tool-watch/latest-report.md`",
            "- `docs/ai-tool-watch/latest-report.json`",
        ]
    )
    return "\n".join(lines) + "\n"


def should_route(report: dict[str, Any], force: bool) -> bool:
    if force:
        return True
    return bool(report.get("changed_sources")) and bool(report.get("high_priority_groups"))


def write_handoff_draft(report: dict[str, Any], draft_dir: Path, dry_run: bool) -> Path | None:
    if not should_route(report, force=False):
        return None
    checked_at = str(report.get("checked_at", ""))
    date = checked_at[:10].replace("-", "") if len(checked_at) >= 10 else dt.date.today().strftime("%Y%m%d")
    slugs = [compact_slug(str(item.get("slug", "source"))) for item in report.get("changed_sources", [])]
    slug = "-".join(slugs[:3]) or "official-sources"
    path = draft_dir / f"{date}_ai_tool_watch_{slug}.md"
    if path.exists():
        return path

    groups = [str(group) for group in report.get("high_priority_groups", [])]
    owner = route_owner(groups)
    body = render_issue_body(report)
    content = (
        f"# Cross-Instance PR: AI Tool Watch Routing ({checked_at})\n\n"
        f"- Owner lane: `{owner}`\n"
        f"- Source report: `docs/ai-tool-watch/latest-report.md`\n"
        f"- NotebookLM harness: `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`\n\n"
        "## Draft Issue Body\n\n"
        f"{body}"
    )
    if dry_run:
        print(f"dry-run: would write {path}")
        return path
    draft_dir.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")
    return path


def create_issue(report: dict[str, Any], repo: str, labels: list[str], dry_run: bool) -> str | None:
    title = build_issue_title(report)
    body = render_issue_body(report)
    for label in labels:
        ensure_label(repo, label, dry_run)
    existing = existing_issue_titles(repo, dry_run)
    if title in existing:
        print(f"skip existing issue: {title}")
        return None
    if dry_run:
        print(f"dry-run: would create issue: {title}")
        return None
    args = ["issue", "create", "--title", title, "--body", body]
    for label in labels:
        args.extend(["--label", label])
    code, out, err = run_gh(args, repo)
    if code != 0:
        print(f"WARN: issue create failed: {err.strip() or out.strip()}", file=sys.stderr)
        return None
    print(out.strip())
    return out.strip()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-json", default="docs/ai-tool-watch/latest-report.json")
    parser.add_argument("--repo", required=True)
    parser.add_argument("--label", action="append", dest="labels", default=[])
    parser.add_argument("--draft-dir", default="docs/cross-instance-prs")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--force", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    args = parse_args(argv)
    report = load_report(repo_path(args.report_json))
    if not should_route(report, args.force):
        print("no high-priority official changes to route")
        return 0

    labels = args.labels or DEFAULT_LABELS
    issue_url = create_issue(report, args.repo, labels, args.dry_run)
    draft = write_handoff_draft(report, repo_path(args.draft_dir), args.dry_run)
    if draft:
        print(f"handoff_draft={draft}")
    if issue_url:
        print(f"issue_url={issue_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
