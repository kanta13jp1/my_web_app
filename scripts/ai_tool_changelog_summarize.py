#!/usr/bin/env python3
"""ai_tool_changelog_summarize.py — Claude Code + Codex CLI 月次 changelog 要約.

Win版#132 part 99 / 2026-04-30 / AI_FLEET_SYNERGY 原則 #3 dogfood.

Input:
  - .ci-logs/claude-code-changelog-<month>.html (= curl で fetch 済 / optional)
  - .ci-logs/codex-cli-releases-<month>.json    (= gh api で fetch 済 / optional)

Output:
  - docs/ai-tool-changelog/<month>.md  (= 構造化 summary / 重要度 H/M/L 付)

Logic:
  1. HTML / JSON を parse
  2. ANTHROPIC_API_KEY あれば Claude haiku で 要約
  3. なければ heuristic な extraction (= 見出し抽出のみ)
  4. fleet 適用候補 (= H 重要度) を別セクションに

= zero-budget でも動く (= Claude API 不在で degraded mode 自動 fallback)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
LOG_DIR = REPO_ROOT / ".ci-logs"
DOC_DIR = REPO_ROOT / "docs" / "ai-tool-changelog"


def parse_github_releases(path: Path) -> list[dict[str, Any]]:
    """GitHub Releases JSON parser (= Claude Code + Codex CLI 共通 / part 102 で統一)."""
    if not path.exists():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return []
    out: list[dict[str, Any]] = []
    for r in data[:15]:
        out.append({
            "name": r.get("name") or r.get("tag_name") or "(untitled)",
            "tag": r.get("tag_name") or "",
            "date": (r.get("published_at") or "")[:10],
            "url": r.get("html_url") or "",
            "body": (r.get("body") or "")[:800],
        })
    return out


def parse_claude_html(path: Path) -> list[dict[str, Any]]:
    """Legacy HTML fallback (= part 99 旧 path 用 / 当面残置)."""
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8", errors="replace")
    matches = re.findall(r"<h2[^>]*>(.*?)</h2>", text, re.DOTALL | re.IGNORECASE)
    out: list[dict[str, Any]] = []
    for h in matches[:15]:
        title = re.sub(r"<[^>]+>", "", h).strip()
        if title:
            out.append({"title": title})
    return out


def heuristic_priority(title: str, body: str = "") -> str:
    """重要度を keyword で雑判定."""
    t = (title + " " + body).lower()
    high_kw = [
        "breaking", "deprecat", "security", "vuln", "rate limit",
        "auth", "subagent", "hook", "mcp", "tool use", "thinking", "memory",
        "skill", "computer use", "automat",
    ]
    medium_kw = ["model", "context", "cache", "stream", "feature", "support"]
    if any(k in t for k in high_kw):
        return "H"
    if any(k in t for k in medium_kw):
        return "M"
    return "L"


def claude_summarize(text_chunks: list[str]) -> str | None:
    """ANTHROPIC_API_KEY 設定時のみ呼ぶ. 失敗時 None で fallback."""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return None
    try:
        import requests  # type: ignore
    except ImportError:
        return None
    prompt = (
        "You summarize Claude Code and OpenAI Codex CLI changelog entries.\n"
        "For each item, output 1 line: '- [H/M/L] <title> — <impact for indie dev fleet of 12 AI instances>'.\n"
        "Use ASCII only. Group by tool (Claude Code / Codex CLI).\n\n"
        "Input chunks:\n"
        + "\n\n---\n\n".join(text_chunks)
    )
    try:
        resp = requests.post(
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
        if resp.status_code != 200:
            return None
        data = resp.json()
        return data.get("content", [{}])[0].get("text", "") or None
    except Exception:  # noqa: BLE001
        return None


def render_markdown(month: str, claude_items: list[dict[str, Any]],
                    codex_items: list[dict[str, Any]],
                    ai_summary: str | None) -> str:
    lines: list[str] = []
    lines.append(f"# AI Tool Changelog {month} (auto-generated)\n")
    lines.append("")
    lines.append(
        "> Win版 part 98-99 で確立した AI_FLEET_SYNERGY #3 dogfood. "
        "monthly cron で Claude Code + Codex CLI の release notes を fetch + summarize.\n"
    )
    lines.append("")

    if ai_summary:
        lines.append("## Claude API 要約")
        lines.append("")
        lines.append(ai_summary)
        lines.append("")

    lines.append("## Anthropic Claude Code (GitHub Releases)")
    lines.append("")
    if claude_items:
        for item in claude_items:
            name = item.get("name", "")
            tag = item.get("tag", "")
            date = item.get("date", "")
            url = item.get("url", "")
            body = item.get("body", "")
            # GitHub Releases JSON 形式 (= name/tag あり) と legacy HTML 形式 (= title のみ) 両対応
            if tag or url:
                pri = heuristic_priority(name, body)
                lines.append(f"- [{pri}] **{name}** ({tag}, {date}) — [link]({url})")
                if body:
                    snippet = body.replace("\n", " ").strip()[:200]
                    lines.append(f"  - {snippet}")
            else:
                title = item.get("title", name)
                pri = heuristic_priority(title)
                lines.append(f"- [{pri}] {title}")
    else:
        lines.append("- (changelog fetch 失敗 or 該当なし)")
    lines.append("")

    lines.append("## OpenAI Codex CLI (GitHub releases)")
    lines.append("")
    if codex_items:
        for item in codex_items:
            name = item.get("name", "")
            tag = item.get("tag", "")
            date = item.get("date", "")
            url = item.get("url", "")
            body = item.get("body", "")
            pri = heuristic_priority(name, body)
            lines.append(f"- [{pri}] **{name}** ({tag}, {date}) — [link]({url})")
            if body:
                snippet = body.replace("\n", " ").strip()[:200]
                lines.append(f"  - {snippet}")
    else:
        lines.append("- (release fetch 失敗 or 該当なし)")
    lines.append("")

    lines.append("## fleet 適用候補 (= 重要度 H 抜粋)")
    lines.append("")
    high_lines = [l for l in lines if l.startswith("- [H]") or l.startswith("- [H] ")]
    if high_lines:
        for l in high_lines:
            lines.append(l)
    else:
        lines.append("- (本月 H 重要度なし)")
    lines.append("")

    lines.append("---")
    lines.append("")
    lines.append(f"*auto-generated by `scripts/ai_tool_changelog_summarize.py` for month {month}*")

    return "\n".join(lines)


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--month", required=True, help="YYYY-MM")
    p.add_argument("--output", required=True, help="output markdown path")
    args = p.parse_args()

    month = args.month
    out_path = REPO_ROOT / args.output
    out_path.parent.mkdir(parents=True, exist_ok=True)

    # Claude Code: 新 GitHub Releases JSON (= part 102 改善) を優先 / なければ legacy HTML へ fallback
    claude_json = LOG_DIR / f"claude-code-releases-{month}.json"
    claude_html = LOG_DIR / f"claude-code-changelog-{month}.html"
    if claude_json.exists():
        claude_items = parse_github_releases(claude_json)
    else:
        claude_items = parse_claude_html(claude_html)

    codex_json = LOG_DIR / f"codex-cli-releases-{month}.json"
    codex_items = parse_github_releases(codex_json)

    text_chunks: list[str] = []
    if claude_items:
        text_chunks.append(
            "Claude Code titles: "
            + ", ".join(i.get("name") or i.get("title", "") for i in claude_items)
        )
    if codex_items:
        text_chunks.append(
            "Codex releases: "
            + "; ".join(
                f"{i.get('name', '')} ({i.get('tag', '')}): {i.get('body', '')[:200]}"
                for i in codex_items
            )
        )

    ai_summary = claude_summarize(text_chunks) if text_chunks else None

    md = render_markdown(month, claude_items, codex_items, ai_summary)
    out_path.write_text(md, encoding="utf-8")
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
