#!/usr/bin/env python3
"""
Add frontmatter (title/tags/published: false) to legacy blog drafts that lack it.

Iterates through docs/blog-drafts/*.md (excluding *-en.md and YYYY-MM-DD.md daily reports).
For each draft without "title:" frontmatter:
  1. Reads content
  2. Calls Claude Haiku API to propose title + tags
  3. Prepends frontmatter
  4. Writes file back

Env vars:
- ANTHROPIC_API_KEY (required)
- DRY_RUN (optional, "true" = don't write files)
"""
from __future__ import annotations

import json
import os
import pathlib
import re
import sys
import time

import requests

ANTHROPIC_API = "https://api.anthropic.com/v1/messages"
MODEL = "claude-haiku-4-5-20251001"
MAX_TOKENS = 500

DRAFTS_DIR = pathlib.Path("docs/blog-drafts")
DAILY_REPORT_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\.md$")


def needs_frontmatter(path: pathlib.Path) -> bool:
    """Check if a draft lacks proper frontmatter."""
    if path.name.endswith("-en.md"):
        return False
    if DAILY_REPORT_RE.match(path.name):
        return False
    try:
        text = path.read_text(encoding="utf-8")
    except Exception:
        return False
    if "published: true" in text:
        return False
    # Has title: in first 10 lines
    first_lines = "\n".join(text.splitlines()[:10])
    return "title:" not in first_lines


def propose_frontmatter(api_key: str, path: pathlib.Path, body: str) -> dict:
    """Call Claude to get {title, tags_list}."""
    snippet = body[:1500]
    prompt = f"""以下は既に本文が書かれた技術ブログドラフトです。Qiita 用の frontmatter (title + tags) を提案してください。

## ファイル名 (日付とトピックのヒント)
{path.name}

## 本文冒頭 (1500文字)
{snippet}

## 要件
- title: 30〜60字の魅力的な日本語タイトル (先頭の # 見出しがあればそれを参考に)
- tags: カンマ区切りで 3〜4 個。候補 = Flutter, Supabase, buildinpublic, 個人開発, AI, DeepResearch, Claude, Schedule, EdgeFunctions

## 出力形式 (厳守・JSON のみ)
{{"title": "...", "tags": ["Flutter", "Supabase", "buildinpublic"]}}"""

    resp = requests.post(
        ANTHROPIC_API,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        json={
            "model": MODEL,
            "max_tokens": MAX_TOKENS,
            "messages": [{"role": "user", "content": prompt}],
        },
        timeout=60,
    )
    resp.raise_for_status()
    raw = resp.json()["content"][0]["text"].strip()

    # Extract JSON (may be fenced)
    if raw.startswith("```"):
        raw = re.sub(r"^```(?:json)?", "", raw).strip()
        raw = re.sub(r"```$", "", raw).strip()
    start = raw.find("{")
    end = raw.rfind("}")
    if start < 0 or end < 0:
        raise ValueError(f"No JSON object in response:\n{raw[:300]}")
    return json.loads(raw[start : end + 1])


def fallback_frontmatter(path: pathlib.Path, body: str) -> dict:
    """Heuristic fallback if API fails."""
    # Use first # heading as title
    for line in body.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()[:60]
            break
    else:
        title = path.stem.replace("-", " ")[:60]
    return {"title": title, "tags": ["Flutter", "Supabase", "buildinpublic", "個人開発"]}


def build_frontmatter(title: str, tags: list[str]) -> str:
    # Qiita uses tags:, dev.to uses tags: — same key
    tags_str = ",".join(tags) if tags else "Flutter,Supabase,buildinpublic,個人開発"
    return (
        "---\n"
        f'title: "{title}"\n'
        f"tags: {tags_str}\n"
        "published: false\n"
        "---\n\n"
    )


def process_draft(api_key: str, path: pathlib.Path, dry_run: bool) -> bool:
    """Process a single draft. Returns True if modified."""
    body = path.read_text(encoding="utf-8")
    try:
        fm = propose_frontmatter(api_key, path, body)
        print(f"  ✅ API proposed: title={fm.get('title','?')[:40]}... tags={fm.get('tags')}")
    except Exception as exc:  # noqa: BLE001
        print(f"  ⚠️ API failed: {exc} — using heuristic fallback", file=sys.stderr)
        fm = fallback_frontmatter(path, body)

    title = fm.get("title") or fallback_frontmatter(path, body)["title"]
    tags = fm.get("tags") or ["Flutter", "Supabase", "buildinpublic"]
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",") if t.strip()]

    frontmatter = build_frontmatter(title, tags)
    new_body = frontmatter + body

    if dry_run:
        print(f"  [dry-run] would write {len(new_body)} bytes")
        return True

    path.write_text(new_body, encoding="utf-8")
    print(f"  💾 wrote {path}")
    return True


def main() -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not api_key:
        print("⚠️ ANTHROPIC_API_KEY not set — will use heuristic fallback for all drafts", file=sys.stderr)
    dry_run = os.environ.get("DRY_RUN", "").lower() == "true"

    targets = [p for p in sorted(DRAFTS_DIR.glob("*.md")) if needs_frontmatter(p)]
    print(f"Found {len(targets)} drafts needing frontmatter")

    modified = 0
    for i, path in enumerate(targets, 1):
        print(f"\n[{i}/{len(targets)}] {path.name}")
        try:
            if process_draft(api_key, path, dry_run):
                modified += 1
        except Exception as exc:  # noqa: BLE001
            print(f"  ❌ {exc}", file=sys.stderr)
            continue
        # Rate limit: Claude Haiku allows ~50 rpm, pace ourselves
        if i < len(targets):
            time.sleep(1.5)

    print(f"\n✅ Modified {modified}/{len(targets)} drafts")
    return 0


if __name__ == "__main__":
    sys.exit(main())
