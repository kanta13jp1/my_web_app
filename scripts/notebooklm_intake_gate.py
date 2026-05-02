#!/usr/bin/env python3
"""Route NotebookLM list snapshots into repo-visible intake decisions.

The gate is intentionally conservative: it records normalized NotebookLM
metadata, links obvious duplicates to existing Issues/docs, and emits draft
route candidates instead of creating Issues by default.
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
HARNESS_NOTEBOOK_TITLE = "Codex vs Claude Code: The Ultimate AI Development Synergy"


@dataclass(frozen=True)
class RouteRule:
    slug: str
    issue: int | None
    lane: str
    action: str
    keywords: tuple[str, ...]
    reason: str
    needs_source_policy: bool = True


ROUTE_RULES: tuple[RouteRule, ...] = (
    RouteRule(
        "harness",
        1606,
        "NotebookLM intake",
        "priority_reference",
        ("codex vs claude code", "ultimate ai development synergy"),
        "Harness notebook; keep as the top routing reference.",
        False,
    ),
    RouteRule(
        "competitive-intel",
        1660,
        "Codex #2 / docs",
        "comment_existing_issue",
        ("competitive", "competitor", "strategic intelligence", "google i/o"),
        "Competitive-intelligence notebooks are already deduplicated into #1660.",
    ),
    RouteRule(
        "claude-code-ops",
        1638,
        "Claude Code",
        "comment_existing_issue",
        ("claude code", "remote control", "schedule", "agentic workflow", "masterclass", "second brain"),
        "Claude Code operations and workflow notebooks route through #1638 unless a narrower issue exists.",
    ),
    RouteRule(
        "workos-authkit-mcp",
        1608,
        "Codex #1 / GitHub Actions",
        "comment_existing_issue",
        ("workos", "authkit", "mcp", "oauth"),
        "WorkOS/AuthKit MCP validation routes through #1608 and #1194.",
    ),
    RouteRule(
        "cursor-gemini-changelog",
        1632,
        "Codex #2",
        "comment_existing_issue",
        ("cursor", "gemini code assist", "gemini"),
        "External coding-agent changelog notebooks route through #1632.",
    ),
    RouteRule(
        "devin-release-notes",
        1629,
        "Codex #2",
        "comment_existing_issue",
        ("devin",),
        "Devin release-note intake routes through #1629.",
    ),
    RouteRule(
        "notion-api",
        1576,
        "Codex #5 / Notion",
        "comment_existing_issue",
        ("notion", "database id", "api page", "property"),
        "Notion database/API notebooks route through the Notion preflight lane.",
    ),
    RouteRule(
        "release-notes",
        1683,
        "Codex #2",
        "comment_existing_issue",
        ("release notes", "release note", "home route"),
        "Release Notes automation is tracked by #1683 with UI intake in #1682.",
    ),
    RouteRule(
        "ai-tool-watch",
        1559,
        "Codex #2 / GitHub Actions",
        "comment_existing_issue",
        ("codex", "openai", "anthropic", "claude", "changelog", "product updates"),
        "AI tool update notebooks route through #1559 after official-source verification.",
    ),
)


SKIP_KEYWORDS: tuple[tuple[str, str], ...] = (
    ("recipe", "non_project_topic"),
    ("cooking", "non_project_topic"),
    ("travel", "non_project_topic"),
    ("music practice", "non_project_topic"),
    ("personal diary", "non_project_topic"),
)


def now_iso() -> str:
    return dt.datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def normalize_text(value: str) -> str:
    value = value.lower()
    value = re.sub(r"[^a-z0-9]+", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def title_key(value: str) -> str:
    words = [word for word in normalize_text(value).split() if len(word) > 2]
    return " ".join(words[:12])


def run_command(args: list[str], cwd: Path, timeout_seconds: int) -> tuple[int, str, str]:
    try:
        result = subprocess.run(
            args,
            cwd=cwd,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout_seconds,
        )
        return result.returncode, result.stdout, result.stderr
    except FileNotFoundError:
        return 127, "", f"{args[0]} is unavailable"
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else ""
        stderr = exc.stderr if isinstance(exc.stderr, str) else ""
        return 124, stdout, stderr or f"{args[0]} timed out"


def load_notebook_payload(input_path: Path | None, root: Path, timeout_seconds: int) -> tuple[dict[str, Any], str, str]:
    if input_path:
        return json.loads(input_path.read_text(encoding="utf-8")), "input_file", str(input_path)

    code, stdout, stderr = run_command(["notebooklm", "list", "--json"], root, timeout_seconds)
    if code != 0:
        detail = (stderr or stdout or f"notebooklm exited with {code}").splitlines()[0]
        return {"count": 0, "notebooks": []}, "unavailable", detail[:240]
    try:
        return json.loads(stdout), "notebooklm_cli", "notebooklm list --json"
    except json.JSONDecodeError as exc:
        return {"count": 0, "notebooks": []}, "error", f"invalid notebooklm JSON: {exc}"


def optional_int(value: Any) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def normalize_notebooks(payload: dict[str, Any]) -> list[dict[str, Any]]:
    raw_notebooks = payload.get("notebooks", payload if isinstance(payload, list) else [])
    if not isinstance(raw_notebooks, list):
        return []

    notebooks: list[dict[str, Any]] = []
    for raw in raw_notebooks:
        if not isinstance(raw, dict):
            continue
        notebook_id = str(raw.get("id") or "").strip()
        title = str(raw.get("title") or "").strip()
        if not notebook_id or not title:
            continue

        sources = raw.get("sources")
        source_count = (
            optional_int(raw.get("source_count"))
            or optional_int(raw.get("sources_count"))
            or (len(sources) if isinstance(sources, list) else None)
        )
        updated_at = (
            raw.get("updated_at")
            or raw.get("modified_at")
            or raw.get("last_modified_at")
            or raw.get("last_opened_at")
        )
        notebooks.append(
            {
                "index": optional_int(raw.get("index")),
                "id": notebook_id,
                "title": title,
                "title_key": title_key(title),
                "is_owner": bool(raw.get("is_owner", False)),
                "created_at": raw.get("created_at"),
                "updated_at": updated_at,
                "source_count": source_count,
            }
        )

    return sorted(notebooks, key=lambda item: (item.get("index") is None, item.get("index") or 999999, item["title_key"]))


def gh_issue_index(repo: str | None, root: Path) -> list[dict[str, Any]]:
    if not repo:
        return []
    code, stdout, _ = run_command(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            repo,
            "--state",
            "all",
            "--limit",
            "1000",
            "--json",
            "number,title,body,labels",
        ],
        root,
        timeout_seconds=40,
    )
    if code != 0:
        return []
    try:
        issues = json.loads(stdout)
    except json.JSONDecodeError:
        return []
    return issues if isinstance(issues, list) else []


def iter_reference_files(root: Path) -> list[Path]:
    candidates: list[Path] = []
    fixed = [
        "AGENTS.md",
        "CLAUDE.md",
        "docs/AGENT_TOOL_POLICY.md",
        "docs/AI_FLEET_SYNERGY_PLAYBOOK.md",
        "docs/CODEX_WORKFLOW.md",
        "docs/SCHEDULE_TASKS.md",
        "docs/ai-tool-watch/README.md",
        "docs/ai-tool-watch/latest-report.md",
    ]
    for item in fixed:
        path = root / item
        if path.exists():
            candidates.append(path)

    for directory in [
        root / "docs" / "notebooklm-intake",
        root / "docs" / "issue-fix-plans",
        root / "docs" / "technical",
        root / "supabase" / "migrations",
    ]:
        if directory.exists():
            candidates.extend(path for path in directory.rglob("*") if path.suffix.lower() in {".md", ".json", ".sql"})

    return sorted(set(candidates))


def build_reference_text(root: Path, issues: list[dict[str, Any]]) -> tuple[str, dict[str, list[str]]]:
    parts: list[str] = []
    refs_by_id: dict[str, list[str]] = {}

    for issue in issues:
        number = issue.get("number")
        label = f"issue #{number}"
        body = f"{issue.get('title', '')}\n{issue.get('body', '')}"
        parts.append(body)
        for notebook_id in re.findall(
            r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            body,
            flags=re.IGNORECASE,
        ):
            refs_by_id.setdefault(notebook_id.lower(), []).append(label)

    for path in iter_reference_files(root):
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        rel = path.relative_to(root).as_posix()
        parts.append(text)
        for notebook_id in re.findall(
            r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
            text,
            flags=re.IGNORECASE,
        ):
            refs_by_id.setdefault(notebook_id.lower(), []).append(rel)

    return "\n".join(parts), refs_by_id


def find_route(notebook: dict[str, Any]) -> RouteRule | None:
    title = normalize_text(notebook["title"])
    for rule in ROUTE_RULES:
        if any(keyword in title for keyword in rule.keywords):
            return rule
    return None


def classify_notebook(
    notebook: dict[str, Any],
    reference_text: str,
    refs_by_id: dict[str, list[str]],
) -> dict[str, Any]:
    notebook_id = notebook["id"].lower()
    title = notebook["title"]
    normalized_title = normalize_text(title)
    refs = sorted(set(refs_by_id.get(notebook_id, [])))

    if notebook_id == HARNESS_NOTEBOOK_ID:
        return {
            "disposition": "priority_reference",
            "route": "harness",
            "issue": 1606,
            "lane": "NotebookLM intake",
            "action": "keep_prioritized",
            "reason": "Harness notebook is the mandatory routing reference.",
            "references": refs,
            "needs_source_policy": False,
        }

    if refs:
        return {
            "disposition": "applied",
            "route": "existing-reference",
            "issue": None,
            "lane": "repository",
            "action": "skip",
            "reason": "Notebook id already appears in repository/Issue references.",
            "references": refs[:8],
            "needs_source_policy": False,
        }

    title_tokens = title_key(title)
    if title_tokens and title_tokens in normalize_text(reference_text):
        return {
            "disposition": "applied",
            "route": "existing-title-reference",
            "issue": None,
            "lane": "repository",
            "action": "skip",
            "reason": "Notebook title appears in repository/Issue references.",
            "references": [],
            "needs_source_policy": False,
        }

    route = find_route(notebook)
    if route:
        return {
            "disposition": "routed",
            "route": route.slug,
            "issue": route.issue,
            "lane": route.lane,
            "action": route.action,
            "reason": route.reason,
            "references": [],
            "needs_source_policy": route.needs_source_policy,
        }

    for keyword, reason in SKIP_KEYWORDS:
        if keyword in normalized_title:
            return {
                "disposition": "skipped",
                "route": "skip",
                "issue": None,
                "lane": "none",
                "action": "skip",
                "reason": reason,
                "references": [],
                "needs_source_policy": False,
            }

    return {
        "disposition": "draft_candidate",
        "route": "manual-review",
        "issue": None,
        "lane": "Codex #1 triage",
        "action": "draft_issue_candidate",
        "reason": "No existing reference or route rule matched; review before creating a new request.",
        "references": [],
        "needs_source_policy": True,
    }


def summarize(notebooks: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for notebook in notebooks:
        disposition = notebook["decision"]["disposition"]
        counts[disposition] = counts.get(disposition, 0) + 1
    return counts


def render_markdown(report: dict[str, Any]) -> str:
    counts = report["counts"]
    lines = [
        "# NotebookLM Intake Gate",
        "",
        f"- Generated at: `{report['generated_at']}`",
        f"- Source state: `{report['source_state']}`",
        f"- Notebook count: `{report['notebook_count']}`",
        f"- Harness found: `{report['harness']['found']}`",
        f"- Routed: `{counts.get('routed', 0)}`",
        f"- Draft candidates: `{counts.get('draft_candidate', 0)}`",
        f"- Applied/skipped: `{counts.get('applied', 0) + counts.get('priority_reference', 0)}` / `{counts.get('skipped', 0)}`",
        "",
        "## Harness",
        "",
        f"- `{HARNESS_NOTEBOOK_TITLE}` (`{HARNESS_NOTEBOOK_ID}`)",
        f"- Decision: `{report['harness']['decision']}`",
        "",
        "## Routed Candidates",
        "",
        "| Notebook | Route | Issue | Reason |",
        "| --- | --- | --- | --- |",
    ]
    routed = [
        item for item in report["notebooks"]
        if item["decision"]["disposition"] in {"routed", "draft_candidate", "priority_reference"}
    ]
    for item in routed[:60]:
        decision = item["decision"]
        issue = f"#{decision['issue']}" if decision.get("issue") else "draft"
        title = item["title"].replace("|", "\\|")
        reason = decision["reason"].replace("|", "\\|")
        lines.append(f"| {title} | `{decision['route']}` | {issue} | {reason} |")
    if not routed:
        lines.append("| None | - | - | - |")

    skipped = [item for item in report["notebooks"] if item["decision"]["disposition"] in {"applied", "skipped"}]
    lines.extend(["", "## Applied Or Skipped", "", "| Notebook | Decision | Reason |", "| --- | --- | --- |"])
    for item in skipped[:60]:
        decision = item["decision"]
        title = item["title"].replace("|", "\\|")
        reason = decision["reason"].replace("|", "\\|")
        lines.append(f"| {title} | `{decision['disposition']}` | {reason} |")
    if not skipped:
        lines.append("| None | - | - |")

    lines.extend(
        [
            "",
            "## Next Automation Step",
            "",
            "- Comment routed notebooks on the linked Issue instead of opening duplicates.",
            "- Create a new additional-request Issue only for `draft_candidate` rows after source-policy review.",
            "- Keep NotebookLM claims behind official-source checks when a notebook summarizes third-party product changes.",
            "",
            "<!-- generated-by: scripts/notebooklm_intake_gate.py -->",
        ]
    )
    return "\n".join(lines) + "\n"


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def write_github_outputs(report: dict[str, Any]) -> None:
    output_path = os.environ.get("GITHUB_OUTPUT")
    if not output_path:
        return
    counts = report["counts"]
    lines = [
        f"notebook_count={report['notebook_count']}",
        f"routed_count={counts.get('routed', 0)}",
        f"draft_candidate_count={counts.get('draft_candidate', 0)}",
        f"skipped_count={counts.get('skipped', 0)}",
        f"harness_found={str(report['harness']['found']).lower()}",
    ]
    with open(output_path, "a", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")


def analyze(args: argparse.Namespace) -> dict[str, Any]:
    root = Path(args.root).resolve()
    payload, source_state, source_detail = load_notebook_payload(args.input, root, args.timeout)
    notebooks = normalize_notebooks(payload)
    issues = gh_issue_index(args.repo, root) if not args.no_gh else []
    reference_text, refs_by_id = build_reference_text(root, issues)

    decided: list[dict[str, Any]] = []
    for notebook in notebooks:
        enriched = dict(notebook)
        enriched["decision"] = classify_notebook(notebook, reference_text, refs_by_id)
        decided.append(enriched)

    harness_item = next((item for item in decided if item["id"].lower() == HARNESS_NOTEBOOK_ID), None)
    report = {
        "generated_at": now_iso(),
        "source_state": source_state,
        "source_detail": source_detail,
        "notebook_count": int(payload.get("count", len(notebooks))) if isinstance(payload, dict) else len(notebooks),
        "normalized_count": len(notebooks),
        "issues_loaded": len(issues),
        "harness": {
            "id": HARNESS_NOTEBOOK_ID,
            "title": HARNESS_NOTEBOOK_TITLE,
            "found": harness_item is not None,
            "decision": harness_item["decision"]["disposition"] if harness_item else "missing",
        },
        "counts": summarize(decided),
        "notebooks": decided,
    }
    return report


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--input", type=Path, help="Path to a saved notebooklm list --json payload.")
    parser.add_argument("--repo", default=os.environ.get("GITHUB_REPOSITORY"))
    parser.add_argument("--no-gh", action="store_true", help="Do not query GitHub Issues with gh.")
    parser.add_argument("--timeout", type=int, default=30)
    parser.add_argument("--report", type=Path, default=Path("docs/notebooklm-intake/latest-report.md"))
    parser.add_argument("--json", type=Path, default=Path("docs/notebooklm-intake/latest-report.json"))
    parser.add_argument("--state", type=Path, default=Path("docs/notebooklm-intake/state.json"))
    parser.add_argument("--print-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    root = Path(args.root).resolve()
    report = analyze(args)
    markdown = render_markdown(report)

    if args.print_only:
        print(markdown, end="")
    else:
        report_path = root / args.report if not args.report.is_absolute() else args.report
        json_path = root / args.json if not args.json.is_absolute() else args.json
        state_path = root / args.state if not args.state.is_absolute() else args.state
        write_text(report_path, markdown)
        write_json(json_path, report)
        write_json(
            state_path,
            {
                "updated_at": report["generated_at"],
                "source_state": report["source_state"],
                "notebook_count": report["notebook_count"],
                "counts": report["counts"],
                "harness": report["harness"],
                "decisions": {
                    item["id"]: {
                        "title": item["title"],
                        "disposition": item["decision"]["disposition"],
                        "route": item["decision"]["route"],
                        "issue": item["decision"].get("issue"),
                        "reason": item["decision"]["reason"],
                    }
                    for item in report["notebooks"]
                },
            },
        )
    write_github_outputs(report)
    if report["source_state"] not in {"input_file", "notebooklm_cli"}:
        print(f"NotebookLM source unavailable: {report['source_detail']}", file=sys.stderr)
        return 0
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
