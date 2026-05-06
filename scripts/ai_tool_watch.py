#!/usr/bin/env python3
"""Watch official AI coding tool pages for workflow-relevant changes.

The script is intentionally dependency-free so it can run in GitHub Actions,
Codex sessions, Claude Code hooks, or a plain local shell.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import os
import re
import sys
import textwrap
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


UTC = dt.timezone.utc


@dataclass(frozen=True)
class Source:
    slug: str
    name: str
    url: str
    owner: str


SOURCES: list[Source] = [
    Source(
        "claude-code-changelog",
        "Claude Code changelog",
        "https://code.claude.com/docs/en/changelog",
        "Claude Code",
    ),
    Source(
        "claude-code-hooks",
        "Claude Code hooks reference",
        "https://code.claude.com/docs/en/hooks",
        "Claude Code",
    ),
    Source(
        "claude-code-github-actions",
        "Claude Code GitHub Actions",
        "https://code.claude.com/docs/en/github-actions",
        "Claude Code",
    ),
    Source(
        "codex-changelog",
        "Codex changelog",
        "https://developers.openai.com/codex/changelog",
        "Codex",
    ),
    Source(
        "codex-use-cases",
        "Codex use cases",
        "https://developers.openai.com/codex/use-cases/",
        "Codex",
    ),
    Source(
        "codex-overview",
        "Codex overview",
        "https://openai.com/codex/",
        "Codex",
    ),
    Source(
        "cursor-changelog",
        "Cursor changelog",
        "https://cursor.com/changelog",
        "Cursor",
    ),
    Source(
        "gemini-code-assist-release-notes",
        "Gemini Code Assist release notes",
        "https://developers.google.com/gemini-code-assist/resources/release-notes",
        "Gemini Code Assist",
    ),
    Source(
        "devin-release-notes",
        "Devin release notes",
        "https://docs.devin.ai/release-notes",
        "Devin",
    ),
]


KEYWORDS: dict[str, list[str]] = {
    "hooks": [
        "hook",
        "hooks",
        "SessionStart",
        "UserPromptSubmit",
        "PostToolUse",
        "Stop",
        "StopFailure",
        "ultrareview",
    ],
    "schedule": [
        "automation",
        "automations",
        "schedule",
        "cron",
        "GitHub Actions",
        "workflow",
        "workflow_dispatch",
    ],
    "codex-runtime": [
        "GPT-5.5",
        "GPT-5.4",
        "model picker",
        "in-app browser",
        "browser use",
        "computer use",
        "worktree",
        "subagents",
    ],
    "integration": [
        "MCP",
        "connector",
        "Slack",
        "Linear",
        "GitHub",
        "IDE extension",
        "VSCode",
        "Visual Studio Code",
    ],
    "quality-cost": [
        "OpenTelemetry",
        "cost",
        "quota",
        "rate limit",
        "sandbox",
        "permission",
        "review",
        "CI",
    ],
}


IMPACT_ROUTES: dict[str, dict[str, Any]] = {
    "hooks": {
        "issues": ["#1422", "#1337", "#1350"],
        "action": (
            "Route to Claude Code quality gates: SessionStart/UserPromptSubmit "
            "for session context, PostToolUse/Stop for lint-test feedback."
        ),
    },
    "schedule": {
        "issues": ["#1422", "#862", "#1307", "#1372"],
        "action": (
            "Route to GitHub Actions or Codex Automations: daily source watch, "
            "merge-backlog triage, and deterministic CI/deploy checks."
        ),
    },
    "codex-runtime": {
        "issues": ["#1422", "#1377", "#1375", "#1408"],
        "action": (
            "Route to Codex execution: use newer models for broad refactors, "
            "in-app browser for UI verification, and worktrees for parallel fixes."
        ),
    },
    "integration": {
        "issues": ["#1339", "#1335", "#1405"],
        "action": (
            "Route to connector reliability: MCP/Slack/GitHub integration checks "
            "and NotebookLM knowledge capture."
        ),
    },
    "quality-cost": {
        "issues": ["#1380", "#1374", "#1336", "#1352"],
        "action": (
            "Route to cost and safety controls: deny-by-default checks, budget "
            "routing, and telemetry before wider automation."
        ),
    },
}


HARNESS_NOTEBOOK = {
    "id": "bc58b50b-5fc4-4840-9a62-b397d6d3b65a",
    "title": "Codex vs Claude Code: The Ultimate AI Development Synergy",
}


HARNESS_LANES = [
    (
        "Claude Code",
        "Owns problem framing, architecture, review gates, and hook design.",
    ),
    (
        "Codex #1",
        "Owns cross-cutting implementation, SQL/migration review, "
        "UI/browser QA, and scoped fix PRs.",
    ),
    (
        "Codex #2",
        "Owns CI repair, synchronization, Edge Functions, GitHub Actions, "
        "and deterministic automation.",
    ),
    (
        "GitHub Actions",
        "Owns reproducible proof: lint, tests, deploy checks, stale-audit jobs, "
        "and report artifacts.",
    ),
    (
        "NotebookLM",
        "Acts as external memory and Master Brain; it informs routing but does "
        "not replace repository checks.",
    ),
]


def now_iso() -> str:
    return dt.datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def fetch(url: str, timeout: int) -> tuple[int, str, str | None]:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "my_web_app-ai-tool-watch/1.0 (+https://github.com/kanta13jp1/my_web_app)",
            "Accept": "text/html, text/plain;q=0.9, */*;q=0.8",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = int(getattr(response, "status", 200))
            raw = response.read().decode("utf-8", errors="replace")
            return status, raw, None
    except urllib.error.HTTPError as exc:
        try:
            raw = exc.read().decode("utf-8", errors="replace")
        except Exception:
            raw = ""
        return int(exc.code), raw, f"HTTP {exc.code}"
    except Exception as exc:  # noqa: BLE001 - this is a report tool
        return 0, "", str(exc)


def html_to_text(raw: str) -> str:
    raw = re.sub(r"(?is)<script.*?</script>", " ", raw)
    raw = re.sub(r"(?is)<style.*?</style>", " ", raw)
    raw = re.sub(r"(?is)<noscript.*?</noscript>", " ", raw)
    raw = re.sub(r"(?is)<[^>]+>", " ", raw)
    raw = html.unescape(raw)
    raw = raw.replace("\u00a0", " ")
    return re.sub(r"\s+", " ", raw).strip()


def stable_hash(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def matched_keyword_groups(text: str) -> dict[str, list[str]]:
    lower = text.lower()
    groups: dict[str, list[str]] = {}
    for group, words in KEYWORDS.items():
        hits = [word for word in words if word.lower() in lower]
        if hits:
            groups[group] = hits[:8]
    return groups


def extract_latest_signal(source: Source, text: str) -> str:
    if source.slug == "claude-code-changelog":
        match = re.search(r"\b(\d+\.\d+\.\d+)\s+([A-Z][a-z]+ \d{1,2}, 2026)\b", text)
        if match:
            return f"{match.group(1)} / {match.group(2)}"
    if source.slug == "codex-changelog":
        match = re.search(r"\b(2026-\d{2}-\d{2})\s+([A-Z][A-Za-z0-9 .,/+-]{8,90})", text)
        if match:
            return f"{match.group(1)} / {match.group(2).strip()}"
        match = re.search(r"GPT-5\.5 and Codex app updates", text)
        if match:
            return "GPT-5.5 and Codex app updates"
    if source.slug == "cursor-changelog":
        match = re.search(r"\b(\d+(?:\.\d+)*)\s+([A-Z][a-z]+ \d{1,2}, 2026)\b", text)
        if match:
            return f"{match.group(1)} / {match.group(2)}"
    if source.slug == "gemini-code-assist-release-notes":
        match = re.search(
            r"\b([A-Z][a-z]+ \d{1,2}, 2026)\s+VS Code Gemini Code Assist\s+([0-9.]+)",
            text,
        )
        if match:
            return f"VS Code Gemini Code Assist {match.group(2)} / {match.group(1)}"
        match = re.search(r"\b([A-Z][a-z]+ \d{1,2}, 2026)\b", text)
        if match:
            return match.group(1)
    if source.slug == "devin-release-notes":
        match = re.search(r"\b([A-Z][a-z]+ \d{1,2}, 2026)\b", text)
        if match:
            return match.group(1)
    title = re.search(r"([A-Z][A-Za-z0-9 .,/+-]{8,90})", text)
    return title.group(1).strip() if title else "No title detected"


def snippet_for_groups(text: str, groups: dict[str, list[str]]) -> list[str]:
    snippets: list[str] = []
    sentences = re.split(r"(?<=[.!?])\s+", text)
    needles = [word.lower() for words in groups.values() for word in words]
    for sentence in sentences:
        compact = sentence.strip()
        if len(compact) < 20:
            continue
        lower = compact.lower()
        if any(needle in lower for needle in needles):
            snippets.append(textwrap.shorten(compact, width=180, placeholder="..."))
        if len(snippets) >= 3:
            break
    return snippets


def load_state(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"updated_at": None, "sources": {}}
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def save_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")


def analyze(args: argparse.Namespace) -> tuple[dict[str, Any], dict[str, Any]]:
    state_path = Path(args.state)
    previous = load_state(state_path)
    previous_sources = previous.get("sources", {})
    checked_at = now_iso()

    report_sources: list[dict[str, Any]] = []
    new_state = {"updated_at": checked_at, "sources": {}}

    for source in SOURCES:
        status, raw, error = fetch(source.url, timeout=args.timeout)
        text = html_to_text(raw)
        digest = stable_hash(text) if text else ""
        groups = matched_keyword_groups(text)
        latest_signal = extract_latest_signal(source, text)
        previous_entry = previous_sources.get(source.slug, {})
        changed = bool(previous_entry) and previous_entry.get("hash") != digest
        first_seen = not bool(previous_entry)
        source_report = {
            "slug": source.slug,
            "name": source.name,
            "owner": source.owner,
            "url": source.url,
            "status": status,
            "error": error,
            "hash": digest,
            "previous_hash": previous_entry.get("hash"),
            "changed": changed,
            "first_seen": first_seen,
            "latest_signal": latest_signal,
            "keyword_groups": groups,
            "snippets": snippet_for_groups(text, groups),
        }
        report_sources.append(source_report)
        new_state["sources"][source.slug] = {
            "name": source.name,
            "url": source.url,
            "status": status,
            "hash": digest,
            "latest_signal": latest_signal,
            "keyword_groups": groups,
            "checked_at": checked_at,
        }

    changed_sources = [item for item in report_sources if item["changed"] or item["first_seen"]]
    active_groups = sorted({group for item in report_sources for group in item["keyword_groups"]})
    high_priority_groups = [group for group in active_groups if group in {"hooks", "schedule", "codex-runtime"}]

    report = {
        "checked_at": checked_at,
        "previous_checked_at": previous.get("updated_at"),
        "issue": args.issue,
        "sources": report_sources,
        "changed_sources": changed_sources,
        "active_groups": active_groups,
        "high_priority_groups": high_priority_groups,
        "impact_routes": {group: IMPACT_ROUTES[group] for group in active_groups if group in IMPACT_ROUTES},
    }
    return report, new_state


def render_markdown(report: dict[str, Any]) -> str:
    changed = report["changed_sources"]
    active_groups = report["active_groups"]
    previous = report.get("previous_checked_at") or "first run"
    lines: list[str] = [
        "# AI Tool Watch Report",
        "",
        f"- Checked at: `{report['checked_at']}`",
        f"- Previous check: `{previous}`",
        f"- Changed/new official sources: `{len(changed)}`",
        f"- Active routing groups: `{', '.join(active_groups) if active_groups else 'none'}`",
        "",
        "## Session Start Summary",
    ]

    if changed:
        for item in changed:
            flag = "new" if item["first_seen"] else "changed"
            lines.append(f"- `{flag}` {item['name']}: {item['latest_signal']}")
    else:
        lines.append("- No official source hash changed since the previous check.")

    lines.extend(
        [
            "",
            "## Recommended Actions",
        ]
    )
    if report["impact_routes"]:
        for group, route in report["impact_routes"].items():
            issues = ", ".join(route["issues"])
            lines.append(f"- **{group}** ({issues}): {route['action']}")
    else:
        lines.append("- No routed action detected.")

    lines.extend(["", "## Official Source Signals"])
    for item in report["sources"]:
        status = item["status"]
        status_text = f"HTTP {status}" if status else f"ERROR: {item['error']}"
        groups = ", ".join(item["keyword_groups"].keys()) or "none"
        lines.append(f"- **{item['name']}** ({status_text})")
        lines.append(f"  - URL: {item['url']}")
        lines.append(f"  - Latest signal: {item['latest_signal']}")
        lines.append(f"  - Keyword groups: {groups}")
        for snippet in item["snippets"][:2]:
            lines.append(f"  - Short signal: {snippet}")

    lines.extend(
        [
            "",
            "## NotebookLM Harness Mapping",
            f"- Source notebook: `{HARNESS_NOTEBOOK['title']}` (`{HARNESS_NOTEBOOK['id']}`)",
        ]
    )
    for owner, action in HARNESS_LANES:
        lines.append(f"- **{owner}**: {action}")

    lines.extend(
        [
            "- Practical rule: every detected tool change must become a WBS route, GitHub issue, hook, workflow check, or PR; notes alone are not complete.",
            "",
            "## 12-Instance Routing Reminder",
            "- Claude Code instances take ambiguous design and cross-instance coordination.",
            "- Codex #1 takes mechanical implementation and broad repo scans that need a clean worktree.",
            "- Codex #2 takes failing checks, deploy unblockers, and sync/automation drift.",
            "- Rebalance owners when the WBS top-20 contains repeated manual work, repeated CI failures, or stale handoffs.",
            "",
            "<!-- generated-by: scripts/ai_tool_watch.py -->",
        ]
    )
    return "\n".join(lines) + "\n"


def write_outputs(report: dict[str, Any], report_path: str) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    changed_names = ",".join(item["slug"] for item in report["changed_sources"])
    with open(output, "a", encoding="utf-8") as f:
        f.write(f"changes_count={len(report['changed_sources'])}\n")
        f.write(f"high_priority_count={len(report['high_priority_groups'])}\n")
        f.write(f"changed_sources={changed_names}\n")
        f.write(f"report_path={report_path}\n")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", default="docs/ai-tool-watch/state.json")
    parser.add_argument("--report", default="docs/ai-tool-watch/latest-report.md")
    parser.add_argument("--json", default="docs/ai-tool-watch/latest-report.json")
    parser.add_argument("--issue", default="1422")
    parser.add_argument("--timeout", type=int, default=20)
    parser.add_argument("--no-save-state", action="store_true")
    parser.add_argument(
        "--print-only",
        action="store_true",
        help="Print the report without writing report/json/state files.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    args = parse_args(argv)
    report, new_state = analyze(args)

    rendered = render_markdown(report)
    if args.print_only:
        print(rendered)
        return 0

    report_path = Path(args.report)
    json_path = Path(args.json)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text(rendered, encoding="utf-8", newline="\n")
    save_json(json_path, report)
    if not args.no_save_state:
        save_json(Path(args.state), new_state)

    write_outputs(report, str(report_path))
    print(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
