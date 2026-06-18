#!/usr/bin/env python3
"""Summarize monthly AI tool changelog snapshots into routed Markdown.

Inputs are optional snapshots fetched by `.github/workflows/ai-tool-changelog-watch.yml`:

- `.ci-logs/claude-code-releases-YYYY-MM.json`
- `.ci-logs/claude-code-changelog-YYYY-MM.html` (legacy fallback)
- `.ci-logs/codex-cli-releases-YYYY-MM.json`
- `.ci-logs/cursor-changelog-YYYY-MM.html`
- `.ci-logs/replit-agent4-YYYY-MM.html`
- `.ci-logs/replit-updates-YYYY-MM.html`

The output intentionally keeps each actionable line in `- [H/M/L] ...` format
so `scripts/ai_tool_changelog_to_issues.py` can create follow-up issues.
"""

from __future__ import annotations

import argparse
import html
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
LOG_DIR = REPO_ROOT / ".ci-logs"


def parse_github_releases(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    if not isinstance(data, list):
        return []

    items: list[dict[str, Any]] = []
    for release in data[:15]:
        if not isinstance(release, dict):
            continue
        items.append(
            {
                "name": release.get("name") or release.get("tag_name") or "(untitled)",
                "tag": release.get("tag_name") or "",
                "date": str(release.get("published_at") or "")[:10],
                "url": release.get("html_url") or "",
                "body": str(release.get("body") or "")[:1000],
            }
        )
    return items


def parse_claude_html(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    raw = path.read_text(encoding="utf-8", errors="replace")
    matches = re.findall(r"<h2[^>]*>(.*?)</h2>", raw, re.DOTALL | re.IGNORECASE)
    items: list[dict[str, Any]] = []
    for heading in matches[:15]:
        title = html_to_text(heading)
        if title:
            items.append({"name": title, "body": "", "url": ""})
    return items


def html_to_text(raw: str) -> str:
    raw = re.sub(r"(?is)<script.*?</script>", " ", raw)
    raw = re.sub(r"(?is)<style.*?</style>", " ", raw)
    raw = re.sub(r"(?is)<noscript.*?</noscript>", " ", raw)
    raw = re.sub(r"(?is)<[^>]+>", " ", raw)
    raw = html.unescape(raw)
    raw = raw.replace("\u00a0", " ")
    return re.sub(r"\s+", " ", raw).strip()


def extract_html_title(raw: str, fallback: str) -> str:
    for pattern in (
        r"(?is)<title[^>]*>(.*?)</title>",
        r"(?is)<h1[^>]*>(.*?)</h1>",
        r"(?is)<h2[^>]*>(.*?)</h2>",
    ):
        match = re.search(pattern, raw)
        if match:
            title = html_to_text(match.group(1))
            if title:
                return title[:160]
    return fallback


def extract_date(text: str) -> str:
    match = re.search(
        r"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\.?\s+\d{1,2},\s+20\d{2}\b",
        text,
        flags=re.IGNORECASE,
    )
    return match.group(0) if match else ""


def parse_web_snapshot(path: Path, name: str, url: str) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    raw = path.read_text(encoding="utf-8", errors="replace")
    text = html_to_text(raw)
    if not text:
        return []
    return [
        {
            "name": extract_html_title(raw, name),
            "date": extract_date(text),
            "url": url,
            "body": text[:1200],
            "source": name,
        }
    ]


def heuristic_priority(title: str, body: str = "") -> str:
    text = (title + " " + body).lower()
    high_keywords = [
        "breaking",
        "deprecat",
        "security",
        "vuln",
        "rate limit",
        "auth",
        "subagent",
        "hook",
        "mcp",
        "tool use",
        "thinking",
        "memory",
        "skill",
        "computer use",
        "automat",
        "auto-review",
        "agent 4",
        "parallel agent",
        "canvas",
        "design mode",
        "sdk",
    ]
    medium_keywords = [
        "model",
        "context",
        "cache",
        "stream",
        "feature",
        "support",
        "workflow",
    ]
    if any(keyword in text for keyword in high_keywords):
        return "H"
    if any(keyword in text for keyword in medium_keywords):
        return "M"
    return "L"


def claude_summarize(text_chunks: list[str]) -> str | None:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return None
    try:
        import requests  # type: ignore
    except ImportError:
        return None

    prompt = (
        "Summarize AI coding tool changelog entries.\n"
        "For each item, output one line: "
        "'- [H/M/L] <title> - <impact for a two-instance AI dev fleet>'.\n"
        "Use ASCII only. Group by tool.\n\n"
        + "\n\n---\n\n".join(text_chunks)
    )
    try:
        response = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": "claude-haiku-4-5",
                "max_tokens": 1500,
                "messages": [{"role": "user", "content": prompt}],
            },
            timeout=30,
        )
        if response.status_code != 200:
            return None
        data = response.json()
        return data.get("content", [{}])[0].get("text", "") or None
    except Exception:
        return None


def render_item(item: dict[str, Any]) -> str:
    name = str(item.get("name") or item.get("title") or "(untitled)")
    body = str(item.get("body") or "")
    tag = str(item.get("tag") or "")
    date = str(item.get("date") or "")
    url = str(item.get("url") or "")
    priority = heuristic_priority(name, body)
    meta = ", ".join(part for part in (tag, date) if part)
    suffix = f" ({meta})" if meta else ""
    link = f" - [link]({url})" if url else ""
    return f"- [{priority}] **{name}**{suffix}{link}"


def render_section(lines: list[str], heading: str, items: list[dict[str, Any]]) -> None:
    lines.extend([f"## {heading}", ""])
    if not items:
        lines.extend(["- (no snapshot items)", ""])
        return
    for item in items:
        lines.append(render_item(item))
        body = str(item.get("body") or "").replace("\n", " ").strip()
        if body:
            lines.append(f"  - {body[:220]}")
    lines.append("")


def render_markdown(
    month: str,
    claude_items: list[dict[str, Any]],
    codex_items: list[dict[str, Any]],
    cursor_items: list[dict[str, Any]],
    replit_items: list[dict[str, Any]],
    ai_summary: str | None,
) -> str:
    lines: list[str] = [
        f"# AI Tool Changelog {month} (auto-generated)",
        "",
        "> Monthly official-source watch for Claude Code, Codex CLI, Cursor, and Replit AI tooling.",
        "",
    ]

    if ai_summary:
        lines.extend(["## Claude API Summary", "", ai_summary.strip(), ""])

    render_section(lines, "Anthropic Claude Code", claude_items)
    render_section(lines, "OpenAI Codex CLI", codex_items)
    render_section(lines, "Cursor Changelog", cursor_items)
    render_section(lines, "Replit Agent / Updates", replit_items)

    lines.extend(["## Fleet Adoption Candidates", ""])
    high_lines = [
        line for line in lines
        if line.startswith("- [H]") and "Fleet Adoption Candidates" not in line
    ]
    if high_lines:
        lines.extend(dict.fromkeys(high_lines))
    else:
        lines.append("- (no H-priority items)")
    lines.extend(
        [
            "",
            "---",
            "",
            f"*auto-generated by `scripts/ai_tool_changelog_summarize.py` for month {month}*",
            "",
        ]
    )
    return "\n".join(lines)


def load_inputs(month: str) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    claude_json = LOG_DIR / f"claude-code-releases-{month}.json"
    claude_html = LOG_DIR / f"claude-code-changelog-{month}.html"
    claude_items = parse_github_releases(claude_json) if claude_json.exists() else parse_claude_html(claude_html)

    codex_items = parse_github_releases(LOG_DIR / f"codex-cli-releases-{month}.json")
    cursor_items = parse_web_snapshot(
        LOG_DIR / f"cursor-changelog-{month}.html",
        "Cursor changelog",
        "https://cursor.com/changelog",
    )
    replit_items = [
        *parse_web_snapshot(
            LOG_DIR / f"replit-agent4-{month}.html",
            "Replit Agent 4 official blog",
            "https://replit.com/blog/introducing-agent-4-built-for-creativity",
        ),
        *parse_web_snapshot(
            LOG_DIR / f"replit-updates-{month}.html",
            "Replit updates changelog",
            "https://docs.replit.com/updates/2026/03/13/changelog",
        ),
    ]
    return claude_items, codex_items, cursor_items, replit_items


def build_ai_summary_chunks(
    claude_items: list[dict[str, Any]],
    codex_items: list[dict[str, Any]],
    cursor_items: list[dict[str, Any]],
    replit_items: list[dict[str, Any]],
) -> list[str]:
    chunks: list[str] = []
    for label, items in (
        ("Claude Code", claude_items),
        ("Codex CLI", codex_items),
        ("Cursor", cursor_items),
        ("Replit", replit_items),
    ):
        if not items:
            continue
        chunks.append(
            label + ": " + "; ".join(
                f"{item.get('name', '')}: {str(item.get('body', ''))[:240]}"
                for item in items
            )
        )
    return chunks


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--month", required=True, help="YYYY-MM")
    parser.add_argument("--output", required=True, help="output markdown path")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    month = args.month
    output_path = REPO_ROOT / args.output
    output_path.parent.mkdir(parents=True, exist_ok=True)

    claude_items, codex_items, cursor_items, replit_items = load_inputs(month)
    chunks = build_ai_summary_chunks(claude_items, codex_items, cursor_items, replit_items)
    ai_summary = claude_summarize(chunks) if chunks else None
    markdown = render_markdown(
        month,
        claude_items,
        codex_items,
        cursor_items,
        replit_items,
        ai_summary,
    )
    output_path.write_text(markdown, encoding="utf-8")
    print(f"wrote {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
