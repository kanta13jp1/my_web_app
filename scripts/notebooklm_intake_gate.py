#!/usr/bin/env python3
"""Normalize NotebookLM list output and route unapplied notebooks.

This gate is intentionally dependency-free. It can run during a local Codex
session with the NotebookLM CLI authenticated, or in CI against a previously
captured JSON file.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


UTC = dt.timezone.utc
HARNESS_NOTEBOOK_ID = "bc58b50b-5fc4-4840-9a62-b397d6d3b65a"
HARNESS_TITLE = "Codex vs Claude Code: The Ultimate AI Development Synergy"

SCAN_DIRS = [
    "AGENTS.md",
    "CLAUDE.md",
    ".github",
    "docs",
    "scripts",
    "supabase/functions",
    "supabase/migrations",
]
SKIP_SCAN_DIR_PARTS = {
    ".git",
    ".dart_tool",
    ".firebase",
    ".venv",
    "build",
    "node_modules",
    "__pycache__",
}
TEXT_SUFFIXES = {
    ".dart",
    ".json",
    ".md",
    ".py",
    ".sql",
    ".toml",
    ".ts",
    ".txt",
    ".yaml",
    ".yml",
}


@dataclass(frozen=True)
class CommandResult:
    code: int
    stdout: str
    stderr: str


def now_iso() -> str:
    return dt.datetime.now(UTC).replace(microsecond=0).isoformat().replace(
        "+00:00",
        "Z",
    )


def run_command(args: list[str], cwd: Path, timeout: int) -> CommandResult:
    try:
        proc = subprocess.run(
            args,
            cwd=str(cwd),
            text=True,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        return CommandResult(127, "", str(exc))
    except subprocess.TimeoutExpired as exc:
        return CommandResult(124, exc.stdout or "", exc.stderr or "timeout")
    except OSError as exc:
        return CommandResult(126, "", str(exc))
    return CommandResult(proc.returncode, proc.stdout.strip(), proc.stderr.strip())


def parse_json_maybe_prefixed(raw: str) -> Any:
    raw = raw.strip()
    if not raw:
        raise ValueError("empty JSON input")
    starts = [idx for idx in (raw.find("{"), raw.find("[")) if idx >= 0]
    if starts:
        raw = raw[min(starts) :]
    return json.loads(raw)


def load_json(path: Path, default: Any) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8-sig"))


def save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def slugify_title(title: str) -> str:
    normalized = re.sub(r"\s+", " ", title).strip().lower()
    normalized = re.sub(r"[^a-z0-9\u3040-\u30ff\u3400-\u9fff]+", "-", normalized)
    return normalized.strip("-")[:80] or "untitled"


def notebook_short_id(notebook_id: str) -> str:
    return notebook_id.split("-", 1)[0]


def normalize_notebook(item: dict[str, Any], index: int) -> dict[str, Any]:
    notebook_id = str(item.get("id", "")).strip()
    title = str(item.get("title", "")).strip()
    created_at = item.get("created_at")
    updated_at = item.get("updated_at")
    return {
        "index": int(item.get("index") or index),
        "id": notebook_id,
        "short_id": notebook_short_id(notebook_id),
        "title": title,
        "title_key": slugify_title(title),
        "is_owner": bool(item.get("is_owner", False)),
        "created_at": created_at,
        "updated_at": updated_at,
        "source_count": item.get("source_count"),
        "source_count_state": "from_list" if item.get("source_count") is not None else "not_collected",
    }


def read_notebook_list(args: argparse.Namespace, root: Path) -> list[dict[str, Any]]:
    if args.input_json:
        data = load_json(Path(args.input_json), {})
        notebooks = data.get("notebooks", data if isinstance(data, list) else [])
        if not isinstance(notebooks, list):
            raise ValueError("--input-json does not contain a notebook list")
        return [
            normalize_notebook(item, index + 1)
            for index, item in enumerate(notebooks)
            if isinstance(item, dict)
        ]

    if not args.refresh:
        raise ValueError("Either --refresh or --input-json is required")

    result = run_command(["notebooklm", "list", "--json"], root, args.timeout)
    if result.code != 0:
        raise RuntimeError(result.stderr or result.stdout or "notebooklm list failed")
    data = parse_json_maybe_prefixed(result.stdout)
    notebooks = data.get("notebooks", data if isinstance(data, list) else [])
    if not isinstance(notebooks, list):
        raise ValueError("notebooklm list output does not contain notebooks")
    return [
        normalize_notebook(item, index + 1)
        for index, item in enumerate(notebooks)
        if isinstance(item, dict)
    ]


def metadata_targets(
    notebooks: list[dict[str, Any]],
    mode: str,
    limit: int,
) -> list[dict[str, Any]]:
    if mode == "none":
        return []
    targets: list[dict[str, Any]] = []
    harness = next((item for item in notebooks if item["id"] == HARNESS_NOTEBOOK_ID), None)
    if harness:
        targets.append(harness)
    if mode == "harness":
        return targets[:limit]

    keywords = [
        "claude",
        "codex",
        "schedule",
        "mcp",
        "notion",
        "competitor",
        "strategic",
        "google i/o",
        "cursor",
        "devin",
        "gemini code",
    ]
    for item in notebooks:
        title = item["title"].lower()
        if any(keyword in title for keyword in keywords) and item not in targets:
            targets.append(item)
    if mode == "all":
        for item in notebooks:
            if item not in targets:
                targets.append(item)
    return targets[:limit]


def enrich_metadata(
    notebooks: list[dict[str, Any]],
    args: argparse.Namespace,
    root: Path,
) -> list[dict[str, Any]]:
    if args.metadata == "none":
        return notebooks
    by_id = {item["id"]: dict(item) for item in notebooks}
    for item in metadata_targets(notebooks, args.metadata, args.metadata_limit):
        result = run_command(
            ["notebooklm", "metadata", "-n", item["short_id"], "--json"],
            root,
            args.timeout,
        )
        if result.code != 0:
            by_id[item["id"]]["metadata_error"] = result.stderr or result.stdout
            continue
        try:
            metadata = parse_json_maybe_prefixed(result.stdout)
        except (ValueError, json.JSONDecodeError) as exc:
            by_id[item["id"]]["metadata_error"] = str(exc)
            continue
        sources = metadata.get("sources") if isinstance(metadata, dict) else None
        source_count = len(sources) if isinstance(sources, list) else None
        enriched = by_id[item["id"]]
        enriched["created_at"] = metadata.get("created_at", enriched.get("created_at"))
        enriched["updated_at"] = metadata.get("updated_at", enriched.get("updated_at"))
        enriched["source_count"] = source_count
        enriched["source_count_state"] = "from_metadata" if source_count is not None else "not_available"
        if isinstance(sources, list):
            enriched["source_titles"] = [
                str(source.get("title", "")).strip()
                for source in sources[:5]
                if isinstance(source, dict)
            ]
    return [by_id[item["id"]] for item in notebooks]


def iter_repo_text_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for item in SCAN_DIRS:
        path = root / item
        if not path.exists():
            continue
        if path.is_file():
            files.append(path)
            continue
        for candidate in path.rglob("*"):
            if not candidate.is_file():
                continue
            rel_parts = set(candidate.relative_to(root).parts)
            if rel_parts & SKIP_SCAN_DIR_PARTS:
                continue
            if "notebooklm-intake" in rel_parts:
                continue
            if candidate.suffix.lower() in TEXT_SUFFIXES:
                files.append(candidate)
    return files


def collect_repo_references(root: Path) -> dict[str, list[str]]:
    references: dict[str, list[str]] = {}
    pattern = re.compile(
        r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
        re.IGNORECASE,
    )
    for path in iter_repo_text_files(root):
        try:
            text = path.read_text(encoding="utf-8-sig", errors="ignore")
        except OSError:
            continue
        for match in pattern.finditer(text):
            references.setdefault(match.group(0).lower(), []).append(str(path.relative_to(root)))
    return references


def load_github_issues(args: argparse.Namespace, root: Path) -> list[dict[str, Any]]:
    if args.gh_issues_json:
        data = load_json(Path(args.gh_issues_json), [])
        return data if isinstance(data, list) else []
    if not args.gh_dedup:
        return []
    result = run_command(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            args.repo,
            "--state",
            "all",
            "--limit",
            "5000",
            "--json",
            "number,title,body,url,state,labels",
        ],
        root,
        args.timeout,
    )
    if result.code != 0:
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def issue_label_names(issue: dict[str, Any]) -> list[str]:
    labels = issue.get("labels") or []
    names: list[str] = []
    for label in labels:
        if isinstance(label, dict):
            names.append(str(label.get("name", "")))
        else:
            names.append(str(label))
    return [name for name in names if name]


def match_issue(notebook: dict[str, Any], issues: list[dict[str, Any]]) -> dict[str, Any] | None:
    title_key = notebook["title_key"]
    short_id = notebook["short_id"].lower()
    full_id = notebook["id"].lower()
    title_phrase = re.sub(r"\s+", " ", notebook["title"]).strip().lower()
    for issue in issues:
        issue_title = str(issue.get("title", "")).lower()
        issue_body = str(issue.get("body", "")).lower()
        haystack = f"{issue_title}\n{issue_body}"
        if full_id and full_id in haystack:
            return issue
        if short_id and short_id in haystack:
            return issue
        if title_phrase and (
            title_phrase in issue_title or title_phrase in issue_body
        ):
            return issue
    return None


def static_route(notebook: dict[str, Any]) -> dict[str, str] | None:
    title = notebook["title"].lower()
    if notebook["id"] == HARNESS_NOTEBOOK_ID:
        return {
            "route": "harness-reference",
            "owner": "Claude Code design / Codex scoped execution / GitHub Actions proof",
            "issue": "1606",
            "disposition": "priority_reference",
        }
    if not notebook["title"]:
        return {
            "route": "skip",
            "owner": "Codex #3",
            "issue": "",
            "disposition": "skipped",
            "skip_reason": "empty_title",
        }
    if any(
        token in title
        for token in [
            "competitor",
            "competitive ai intelligence",
            "competitive intelligence",
            "strategic intelligence",
            "google i/o",
            "marketplace trends",
            "multi-agent convergence",
        ]
    ):
        return {
            "route": "competitive-intel",
            "owner": "Codex #2 automation / Codex #3 intake",
            "issue": "1660",
            "disposition": "route_existing_issue",
        }
    if any(
        token in title
        for token in [
            "claude code",
            "codex",
            "schedule",
            "remote control",
            "second brain",
        ]
    ):
        return {
            "route": "ai-dev-workflow",
            "owner": "Claude Code design / Codex automation",
            "issue": "1638",
            "disposition": "route_existing_issue",
        }
    if any(token in title for token in ["mcp", "authkit", "notion database", "notion db"]):
        return {
            "route": "integration-reliability",
            "owner": "Codex #2 synchronization",
            "issue": "1628",
            "disposition": "route_existing_issue",
        }
    if any(token in title for token in ["cursor", "devin", "gemini code", "visual studio code", "dev containers"]):
        return {
            "route": "developer-tool-watch",
            "owner": "Codex #3 intake / Claude Code review",
            "issue": "1628",
            "disposition": "route_existing_issue",
        }
    if any(token in title for token in ["react frontend", "material-ui", "eks manifest"]):
        return {
            "route": "skip",
            "owner": "Codex #3",
            "issue": "",
            "disposition": "skipped",
            "skip_reason": "non_current_stack",
        }
    if "internal review record sheet" in title:
        return {
            "route": "skip",
            "owner": "Codex #3",
            "issue": "",
            "disposition": "skipped",
            "skip_reason": "non_project_compliance_template",
        }
    return None


def build_routing(
    notebooks: list[dict[str, Any]],
    repo_refs: dict[str, list[str]],
    issues: list[dict[str, Any]],
    previous: dict[str, Any],
) -> list[dict[str, Any]]:
    previous_items = previous.get("notebooks", {}) if isinstance(previous, dict) else {}
    checked_at = now_iso()
    routed: list[dict[str, Any]] = []
    for notebook in notebooks:
        prev = previous_items.get(notebook["id"], {})
        route = static_route(notebook) or {}
        issue = None if route.get("issue") else match_issue(notebook, issues)
        repo_paths = repo_refs.get(notebook["id"].lower(), [])
        disposition = route.get("disposition") or "candidate_issue_draft"
        issue_number = route.get("issue") or ""
        issue_url = ""
        if issue:
            issue_number = str(issue.get("number", ""))
            issue_url = str(issue.get("url", ""))
            disposition = "route_existing_issue"
        elif repo_paths and not route:
            disposition = "applied_in_repo"
        elif prev.get("disposition") == "skipped" and prev.get("skip_reason"):
            disposition = "skipped"
            route["skip_reason"] = str(prev.get("skip_reason"))
        routed.append(
            {
                **notebook,
                "first_seen_at": prev.get("first_seen_at") or checked_at,
                "last_seen_at": checked_at,
                "route": route.get("route") or "unclassified",
                "owner": route.get("owner") or "Claude Code triage / Codex scoped implementation",
                "disposition": disposition,
                "skip_reason": route.get("skip_reason") or "",
                "existing_issue_number": issue_number,
                "existing_issue_url": issue_url,
                "repo_references": repo_paths[:8],
            }
        )
    return routed


def render_report(snapshot: dict[str, Any]) -> str:
    notebooks = snapshot["notebooks"]
    candidates = [item for item in notebooks if item["disposition"] == "candidate_issue_draft"]
    routed = [item for item in notebooks if item["disposition"] == "route_existing_issue"]
    skipped = [item for item in notebooks if item["disposition"] == "skipped"]
    applied = [item for item in notebooks if item["disposition"] in {"applied_in_repo", "priority_reference"}]
    lines = [
        "# NotebookLM Intake Gate Report",
        "",
        f"- Checked at: `{snapshot['checked_at']}`",
        f"- Notebook count: `{len(notebooks)}`",
        f"- Harness found: `{snapshot['harness_found']}`",
        f"- Routed to existing issues: `{len(routed)}`",
        f"- Applied/reference notebooks: `{len(applied)}`",
        f"- Candidate issue drafts: `{len(candidates)}`",
        f"- Skipped notebooks: `{len(skipped)}`",
        "",
        "## Harness",
        f"- `{HARNESS_NOTEBOOK_ID}`: {HARNESS_TITLE}",
        "- NotebookLM informs routing; repo checks, official sources, CI, and Issues/WBS prove the result.",
        "",
        "## Routed Existing Issues",
    ]
    if routed:
        for item in routed[:40]:
            issue = f"#{item['existing_issue_number']}" if item["existing_issue_number"] else "existing route"
            lines.append(
                f"- `{item['short_id']}` {item['title'] or '(untitled)'} -> {issue} / {item['route']}"
            )
    else:
        lines.append("- None.")

    lines.extend(["", "## Candidate Issue Drafts"])
    if candidates:
        for item in candidates[:40]:
            lines.append(
                f"- `{item['short_id']}` {item['title'] or '(untitled)'} -> {item['route']}"
            )
    else:
        lines.append("- None.")

    lines.extend(["", "## Skipped"])
    if skipped:
        for item in skipped[:40]:
            reason = item["skip_reason"] or "not_project_relevant"
            lines.append(f"- `{item['short_id']}` {item['title'] or '(untitled)'}: {reason}")
    else:
        lines.append("- None.")

    lines.extend(["", "## Normalized Notebook Snapshot"])
    lines.append("| id | title | sources | created_at | updated_at | disposition |")
    lines.append("| --- | --- | ---: | --- | --- | --- |")
    for item in notebooks[:80]:
        source_count = item["source_count"] if item["source_count"] is not None else ""
        title = (item["title"] or "(untitled)").replace("|", "\\|")
        lines.append(
            f"| `{item['short_id']}` | {title} | {source_count} | "
            f"{item.get('created_at') or ''} | {item.get('updated_at') or ''} | "
            f"{item['disposition']} |"
        )
    lines.extend(["", "<!-- generated-by: scripts/notebooklm_intake_gate.py -->"])
    return "\n".join(lines) + "\n"


def render_issue_drafts(snapshot: dict[str, Any]) -> str:
    candidates = [
        item for item in snapshot["notebooks"]
        if item["disposition"] == "candidate_issue_draft"
    ]
    lines = [
        "# NotebookLM Intake Issue Drafts",
        "",
        f"Generated: `{snapshot['checked_at']}`",
        "",
    ]
    if not candidates:
        lines.append("No new issue drafts. Existing routes or skip reasons cover all notebooks.")
        lines.append("")
        return "\n".join(lines)
    for item in candidates:
        title = item["title"] or "(untitled NotebookLM source)"
        lines.extend(
            [
                f"## [追加要望][P2] NotebookLM source intake: {title}",
                "",
                "Labels: `enhancement`, `追加要望`, `wbs`, `automation`",
                "",
                "### Background",
                "",
                f"- Notebook ID: `{item['id']}`",
                f"- Created: `{item.get('created_at') or 'unknown'}`",
                f"- Source count: `{item.get('source_count') if item.get('source_count') is not None else 'unknown'}`",
                f"- Proposed route: `{item['route']}`",
                "",
                "### Request",
                "",
                "Review this NotebookLM source with primary-source verification, then route verified work into an existing Issue/WBS task before creating a new implementation issue.",
                "",
                "### Acceptance Criteria",
                "",
                "- [ ] Duplicate GitHub Issues and WBS tasks were searched.",
                "- [ ] NotebookLM claims were verified against official or primary sources where needed.",
                "- [ ] Findings were routed to an existing Issue/WBS task or this draft was promoted into a new additional-request Issue.",
                "- [ ] A skip reason was recorded if the notebook is out of project scope.",
                "",
            ],
        )
    return "\n".join(lines)


def write_github_outputs(snapshot: dict[str, Any]) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        return
    notebooks = snapshot["notebooks"]
    counts: dict[str, int] = {}
    for item in notebooks:
        counts[item["disposition"]] = counts.get(item["disposition"], 0) + 1
    lines = [
        f"notebook_count={snapshot['notebook_count']}",
        f"harness_found={str(snapshot['harness_found']).lower()}",
        f"routed_count={counts.get('route_existing_issue', 0)}",
        f"candidate_issue_draft_count={counts.get('candidate_issue_draft', 0)}",
        f"skipped_count={counts.get('skipped', 0)}",
        f"applied_count={counts.get('applied_in_repo', 0) + counts.get('priority_reference', 0)}",
    ]
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="Run notebooklm list --json.")
    parser.add_argument("--input-json", help="Read notebooklm list JSON from a file.")
    parser.add_argument("--state", default="docs/notebooklm-intake/state.json")
    parser.add_argument("--snapshot", default="docs/notebooklm-intake/latest-snapshot.json")
    parser.add_argument("--report", default="docs/notebooklm-intake/latest-report.md")
    parser.add_argument("--issue-drafts", default="docs/notebooklm-intake/issue-drafts.md")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY", "kanta13jp1/my_web_app"))
    parser.add_argument("--gh-dedup", action="store_true", help="Fetch GitHub Issues for duplicate routing.")
    parser.add_argument("--gh-issues-json", help="Read GitHub Issues JSON from a file.")
    parser.add_argument(
        "--metadata",
        choices=["none", "harness", "routed", "all"],
        default="harness",
        help="Fetch NotebookLM metadata for source counts.",
    )
    parser.add_argument("--metadata-limit", type=int, default=12)
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--print-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    args = parse_args(argv)
    root = Path.cwd()
    previous = load_json(Path(args.state), {"notebooks": {}})
    checked_at = now_iso()
    notebooks = read_notebook_list(args, root)
    notebooks = enrich_metadata(notebooks, args, root)
    issues = load_github_issues(args, root)
    repo_refs = collect_repo_references(root)
    routed = build_routing(notebooks, repo_refs, issues, previous)
    snapshot = {
        "checked_at": checked_at,
        "harness_notebook_id": HARNESS_NOTEBOOK_ID,
        "harness_found": any(item["id"] == HARNESS_NOTEBOOK_ID for item in routed),
        "notebook_count": len(routed),
        "notebooks": routed,
    }
    report = render_report(snapshot)
    issue_drafts = render_issue_drafts(snapshot)
    write_github_outputs(snapshot)
    if args.print_only:
        print(report)
        print(issue_drafts)
        return 0

    save_json(Path(args.snapshot), snapshot)
    state = {
        "updated_at": checked_at,
        "notebooks": {
            item["id"]: {
                "title": item["title"],
                "first_seen_at": item["first_seen_at"],
                "last_seen_at": item["last_seen_at"],
                "route": item["route"],
                "disposition": item["disposition"],
                "skip_reason": item["skip_reason"],
                "existing_issue_number": item["existing_issue_number"],
            }
            for item in routed
        },
    }
    save_json(Path(args.state), state)
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(report, encoding="utf-8", newline="\n")
    Path(args.issue_drafts).write_text(issue_drafts, encoding="utf-8", newline="\n")
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
