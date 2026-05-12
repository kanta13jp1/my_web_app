#!/usr/bin/env python3
"""Route AI Tool Watch findings into GitHub issues and handoff drafts.

This is the deterministic bridge for the daily official-source watch:

1. Read docs/ai-tool-watch/latest-report.json.
2. If official sources changed and at least one high-priority routing group is
   active, create or update one deduplicated GitHub issue.
3. Write a two-instance handoff draft and a PR skeleton draft that the workflow
   can commit with the watch report.

The WBS handoff stays issue-first. The existing GitHub Issues WBS Sync workflow
mirrors the created issue into Supabase WBS without this script requiring
service-role credentials.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import re
import subprocess
import sys
from dataclasses import dataclass
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
    "ai-tool-watch": "Official AI tool source watch routing",
    "ai-tool-update": "AI tool update adoption and implementation tracking",
    "追加要望": "Feature or workflow request",
}


@dataclass(frozen=True)
class RouteDecision:
    owner: str
    instance: str
    due_hint: str
    risk: str
    implementation_shape: str


def repo_path(path_text: str) -> Path:
    path = Path(path_text)
    return path if path.is_absolute() else REPO_ROOT / path


def repo_relative(path: Path) -> str:
    try:
        return path.relative_to(REPO_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


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
    code, out, err = run_gh(["label", "list", "--limit", "500", "--json", "name"], repo)
    if code != 0:
        print(f"WARN: cannot list labels for {label}: {err.strip()}", file=sys.stderr)
        return
    try:
        labels = {item.get("name", "") for item in json.loads(out)}
    except json.JSONDecodeError:
        labels = set()
    if label in labels:
        return
    code, _, err = run_gh(
        [
            "label",
            "create",
            label,
            "--color",
            LABEL_COLORS.get(label, "00897B"),
            "--description",
            LABEL_DESCRIPTIONS.get(label, "AI tool watch routing"),
        ],
        repo,
    )
    if code != 0:
        print(f"WARN: label create failed for {label}: {err.strip()}", file=sys.stderr)


def changed_source_names(report: dict[str, Any]) -> list[str]:
    names: list[str] = []
    for item in report.get("changed_sources", []):
        names.append(str(item.get("name") or item.get("slug") or "official source"))
    return names


def route_groups(report: dict[str, Any]) -> list[str]:
    groups = [str(group) for group in report.get("high_priority_groups", []) if group]
    if groups:
        return sorted(dict.fromkeys(groups))
    return sorted(
        dict.fromkeys(str(group) for group in report.get("active_groups", []) if group)
    )


def decide_route(groups: list[str]) -> RouteDecision:
    group_set = set(groups)
    if "schedule" in group_set:
        return RouteDecision(
            owner="Codex #1",
            instance="codex",
            due_hint="next WBS sprint pickup unless an existing issue already owns the signal",
            risk="workflow or automation changes must stay scoped and CI-proven",
            implementation_shape="GitHub Actions / script update with deterministic tests",
        )
    if "codex-runtime" in group_set:
        return RouteDecision(
            owner="Codex #1",
            instance="codex",
            due_hint="route after Claude Code #1 adoption decision",
            risk="model/runtime claims must be official-source verified before implementation",
            implementation_shape="small repo workflow, UI QA, or developer-experience PR",
        )
    if "hooks" in group_set:
        return RouteDecision(
            owner="Claude Code #1",
            instance="claude",
            due_hint="design/review gate first, then Codex #1 scoped implementation if needed",
            risk="hook policy changes can affect every session and need human-readable spec",
            implementation_shape="spec or hook-policy PR followed by Codex #1 implementation",
        )
    return RouteDecision(
        owner="Claude Code #1",
        instance="claude",
        due_hint="manual adoption triage required",
        risk="unclear routing group",
        implementation_shape="triage comment or docs-only decision record",
    )


def should_route(report: dict[str, Any], force: bool = False) -> bool:
    if force:
        return True
    return bool(report.get("changed_sources")) and bool(report.get("high_priority_groups"))


def checked_date(report: dict[str, Any]) -> str:
    checked_at = str(report.get("checked_at") or "")
    if len(checked_at) >= 10:
        return checked_at[:10]
    return dt.datetime.now(dt.timezone.utc).date().isoformat()


def compact_slug(value: str) -> str:
    lowered = value.lower()
    lowered = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return lowered or "source"


def build_issue_title(report: dict[str, Any]) -> str:
    names = changed_source_names(report) or ["official AI tool source"]
    source_text = ", ".join(names[:3])
    if len(names) > 3:
        source_text += f", +{len(names) - 3}"
    return f"[ai-tool-watch] {checked_date(report)} official AI tool changes: {source_text}"[:180]


def source_lines(report: dict[str, Any]) -> list[str]:
    lines: list[str] = []
    for item in report.get("changed_sources", []):
        groups = ", ".join((item.get("keyword_groups") or {}).keys()) or "none"
        lines.extend(
            [
                f"- **{item.get('name', item.get('slug', 'official source'))}**",
                f"  - URL: {item.get('url', '')}",
                f"  - Latest signal: `{item.get('latest_signal', 'unknown')}`",
                f"  - Keyword groups: `{groups}`",
            ]
        )
    if not lines:
        lines.append("- No changed source listed. This route was force-generated.")
    return lines


def recommended_action_lines(report: dict[str, Any]) -> list[str]:
    routes = report.get("impact_routes") or {}
    if not routes:
        return ["- No deterministic route was found; inspect the source report manually."]
    lines: list[str] = []
    for group in sorted(routes):
        route = routes[group]
        issues = ", ".join(route.get("issues", []))
        lines.append(f"- **{group}** ({issues or 'no linked issue'}): {route.get('action', '')}")
    return lines


def render_issue_body(report: dict[str, Any], handoff_path: str, pr_skeleton_path: str) -> str:
    groups = route_groups(report)
    decision = decide_route(groups)
    checked_at = report.get("checked_at", "unknown")
    lines: list[str] = [
        "## Summary",
        "",
        "AI Tool Watch detected official AI tool source changes that need repository routing.",
        "",
        f"- Checked at: `{checked_at}`",
        f"- Routing groups: `{', '.join(groups) if groups else 'none'}`",
        f"- Proposed owner: `{decision.owner}`",
        f"- Proposed WBS instance: `{decision.instance}`",
        f"- Due hint: `{decision.due_hint}`",
        f"- Risk: `{decision.risk}`",
        "",
        "## Changed Sources",
        "",
        *source_lines(report),
        "",
        "## Recommended Actions",
        "",
        *recommended_action_lines(report),
        "",
        "## Two-Instance Route",
        "",
        "- Claude Code #1 owns ambiguous adoption decisions, architecture, review policy, and hook design.",
        "- Codex #1 owns scoped implementation, GitHub Actions, Edge Functions, CI/deploy proof, and cleanup.",
        "- Legacy Codex #2/#3 lanes are dormant and are absorbed by Codex #1.",
        "",
        "## WBS Route",
        "",
        "- category: `automation`",
        f"- instance: `{decision.instance}`",
        f"- owner: `{decision.owner}`",
        f"- implementation shape: `{decision.implementation_shape}`",
        "- sync path: GitHub Issues WBS Sync mirrors this issue into `wbs_tasks`.",
        "",
        "## Draft Artifacts",
        "",
        f"- Handoff draft: `{handoff_path}`",
        f"- PR skeleton draft: `{pr_skeleton_path}`",
        "",
        "## Acceptance Criteria",
        "",
        "- [ ] Decide adopt / defer / ignore for each changed official signal.",
        "- [ ] Route adopted items to an implementation issue, workflow check, hook, or scoped PR.",
        "- [ ] Avoid duplicate issues by updating this issue when the same watch title recurs.",
        "- [ ] Confirm WBS has a matching task or an explicit no-op record.",
        "- [ ] Keep implementation inside the Claude Code #1 + Codex #1 two-instance policy.",
        "",
        "## Source Report",
        "",
        "- `docs/ai-tool-watch/latest-report.md`",
        "- `docs/ai-tool-watch/latest-report.json`",
    ]
    return "\n".join(lines) + "\n"


def render_update_comment(report: dict[str, Any], handoff_path: str, pr_skeleton_path: str) -> str:
    groups = route_groups(report)
    decision = decide_route(groups)
    names = ", ".join(changed_source_names(report)[:5]) or "none"
    return "\n".join(
        [
            "## AI Tool Watch route update",
            "",
            f"- Checked at: `{report.get('checked_at', 'unknown')}`",
            f"- Changed sources: `{names}`",
            f"- Routing groups: `{', '.join(groups) if groups else 'none'}`",
            f"- Proposed owner: `{decision.owner}`",
            f"- Handoff draft: `{handoff_path}`",
            f"- PR skeleton draft: `{pr_skeleton_path}`",
            "",
            "Existing issue reused; no duplicate issue was created.",
        ]
    ) + "\n"


def draft_paths(report: dict[str, Any], draft_dir: Path) -> tuple[Path, Path]:
    date = checked_date(report).replace("-", "")
    slugs = [compact_slug(str(item.get("slug", "source"))) for item in report.get("changed_sources", [])]
    slug = "-".join(slugs[:3]) or "official-sources"
    base = f"{date}_ai_tool_watch_{slug}"
    return draft_dir / f"{base}_handoff.md", draft_dir / f"{base}_pr_skeleton.md"


def render_handoff_draft(report: dict[str, Any], pr_skeleton_path: str) -> str:
    groups = route_groups(report)
    decision = decide_route(groups)
    return "\n".join(
        [
            f"# AI Tool Watch Handoff {checked_date(report)}",
            "",
            "Auto-generated by `scripts/ai_tool_watch_route.py`.",
            "",
            "## Routing",
            "",
            f"- Owner lane: `{decision.owner}`",
            f"- WBS instance: `{decision.instance}`",
            f"- Routing groups: `{', '.join(groups) if groups else 'none'}`",
            "- Source report: `docs/ai-tool-watch/latest-report.md`",
            "- Source JSON: `docs/ai-tool-watch/latest-report.json`",
            f"- PR skeleton: `{pr_skeleton_path}`",
            "",
            "## Changed Sources",
            "",
            *source_lines(report),
            "",
            "## Delegation Packet",
            "",
            "- WBS / Issue: created or updated by this router.",
            f"- Due date: {decision.due_hint}",
            "- Current owners: Claude Code #1 + Codex #1 only.",
            "- Objective: convert official tool changes into a concrete adoption decision and scoped implementation route.",
            "- Allowed write set: docs, scripts, GitHub Actions, tests, and scoped product code after adoption decision.",
            "- Prohibited write set: unrelated refactors, live secrets, dormant old Codex lanes.",
            "- Required validation: unit tests for scripts, workflow syntax review, PR checks green, deploy/WBS Sync after merge.",
            "- Memory/disk hygiene: record pre/post C: free space, top memory process, cleanup actions, and skipped parent-app processes.",
            "",
            "## Result Contract",
            "",
            "- Changed files:",
            "- Validation result:",
            "- PR / Issue links:",
            "- Remaining risk:",
            "- Next owner:",
            "",
        ]
    )


def render_pr_skeleton(report: dict[str, Any]) -> str:
    groups = route_groups(report)
    decision = decide_route(groups)
    title = build_issue_title(report)
    return "\n".join(
        [
            f"# PR Skeleton: {title}",
            "",
            "Auto-generated by `scripts/ai_tool_watch_route.py`.",
            "",
            "## Proposed PR Title",
            "",
            f"`chore(ai-tool): route {checked_date(report)} official updates`",
            "",
            "## Scope",
            "",
            f"- Owner: `{decision.owner}`",
            f"- Implementation shape: `{decision.implementation_shape}`",
            "- Keep the PR scoped to one adoption decision or one automation update.",
            "- Do not start dormant Codex #2/#3 lanes; Codex #1 absorbs implementation work.",
            "",
            "## Changed Source Evidence",
            "",
            *source_lines(report),
            "",
            "## Suggested Validation",
            "",
            "- `python -m py_compile scripts/ai_tool_watch.py scripts/ai_tool_watch_route.py`",
            "- `python -m unittest test.scripts.test_ai_tool_watch_route`",
            "- `git diff --check`",
            "- PR checks green",
            "",
            "## Merge Follow-Up",
            "",
            "- Confirm Deploy to Production success when applicable.",
            "- Confirm GitHub Issues WBS Sync success.",
            "- Cleanup branch/worktree and record memory/HDD compression actions.",
            "",
        ]
    )


def write_drafts(report: dict[str, Any], draft_dir: Path, dry_run: bool) -> tuple[str, str]:
    handoff_path, pr_path = draft_paths(report, draft_dir)
    handoff_rel = repo_relative(handoff_path)
    pr_rel = repo_relative(pr_path)
    if dry_run:
        print(f"dry-run: would write {handoff_rel}")
        print(f"dry-run: would write {pr_rel}")
        return handoff_rel, pr_rel
    draft_dir.mkdir(parents=True, exist_ok=True)
    handoff_path.write_text(render_handoff_draft(report, pr_rel), encoding="utf-8", newline="\n")
    pr_path.write_text(render_pr_skeleton(report), encoding="utf-8", newline="\n")
    return handoff_rel, pr_rel


def find_existing_issue(repo: str, title: str, dry_run: bool) -> int | None:
    if dry_run:
        return None
    code, out, err = run_gh(
        [
            "issue",
            "list",
            "--state",
            "all",
            "--search",
            f"{title} in:title",
            "--json",
            "number,title",
            "--limit",
            "20",
        ],
        repo,
    )
    if code != 0:
        print(f"WARN: issue search failed; dedup disabled: {err.strip()}", file=sys.stderr)
        return None
    try:
        for item in json.loads(out):
            if item.get("title") == title:
                return int(item["number"])
    except (json.JSONDecodeError, KeyError, TypeError, ValueError):
        return None
    return None


def create_or_update_issue(
    report: dict[str, Any],
    repo: str,
    labels: list[str],
    handoff_path: str,
    pr_skeleton_path: str,
    dry_run: bool,
) -> str | None:
    title = build_issue_title(report)
    body = render_issue_body(report, handoff_path, pr_skeleton_path)
    if dry_run:
        print(f"dry-run: would create/update issue: {title}")
        return None

    for label in labels:
        ensure_label(repo, label, dry_run=False)

    existing = find_existing_issue(repo, title, dry_run=False)
    if existing is not None:
        comment = render_update_comment(report, handoff_path, pr_skeleton_path)
        code, out, err = run_gh(["issue", "comment", str(existing), "--body", comment], repo)
        if code == 0:
            url = out.strip()
            print(f"updated_issue=#{existing}")
            print(url)
            return url
        print(f"WARN: issue comment failed: {err.strip() or out.strip()}", file=sys.stderr)
        return None

    args = ["issue", "create", "--title", title, "--body", body]
    for label in labels:
        args.extend(["--label", label])
    code, out, err = run_gh(args, repo)
    if code == 0:
        url = out.strip()
        print(url)
        return url
    print(f"WARN: issue create failed: {err.strip() or out.strip()}", file=sys.stderr)
    return None


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-json", default="docs/ai-tool-watch/latest-report.json")
    parser.add_argument("--repo", required=True)
    parser.add_argument("--label", action="append", dest="labels", default=[])
    parser.add_argument("--draft-dir", default="docs/cross-instance-prs/drafts/ai-tool-watch")
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
    if not should_route(report, force=args.force):
        print("no high-priority official changes to route")
        return 0

    handoff_path, pr_skeleton_path = write_drafts(report, repo_path(args.draft_dir), args.dry_run)
    issue_url = create_or_update_issue(
        report,
        args.repo,
        args.labels or DEFAULT_LABELS,
        handoff_path,
        pr_skeleton_path,
        args.dry_run,
    )
    print(f"handoff_draft={handoff_path}")
    print(f"pr_skeleton={pr_skeleton_path}")
    if issue_url:
        print(f"issue_url={issue_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
