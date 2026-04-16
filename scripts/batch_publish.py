#!/usr/bin/env python3
"""
Batch publish all unpublished blog drafts to Qiita/dev.to.

Env vars:
- SUPABASE_KEY: Supabase service role key
- MAX_POSTS: max number of posts (default 999)
- DELAY: seconds between posts (default 30)
- DRY_RUN: "true" = list only, "false" = actually publish
- PLATFORMS: "qiita" | "devto" | "qiita,devto"
"""
from __future__ import annotations

import os
import sys
import time
import json
import pathlib
import re

import requests

SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")
MAX_POSTS = int(os.environ.get("MAX_POSTS", "999"))
DELAY = int(os.environ.get("DELAY", "30"))
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() == "true"
PLATFORMS = os.environ.get("PLATFORMS", "qiita")

DRAFTS_FILE = "/tmp/drafts.txt"


def _mark_published(path: pathlib.Path) -> bool:
    """Add published: true to a draft file. Returns True if file was modified."""
    text = path.read_text(encoding="utf-8")
    if "published: true" in text:
        return False  # already marked

    if "published: false" in text:
        new_text = text.replace("published: false", "published: true", 1)
    elif text.startswith("---"):
        # Has frontmatter but no published line — insert after first ---
        new_text = text.replace("---\n", "---\npublished: true\n", 1)
    else:
        # No frontmatter — prepend minimal one
        new_text = f"---\npublished: true\n---\n{text}"

    if new_text != text:
        path.write_text(new_text, encoding="utf-8")
        return True
    return False


def extract_title(path: pathlib.Path) -> str:
    text = path.read_text(encoding="utf-8")
    # Try YAML frontmatter title:
    m = re.search(r"^title:\s*['\"]?(.*?)['\"]?\s*$", text, re.MULTILINE)
    if m:
        return m.group(1).strip()
    # Fall back to first # heading
    m = re.search(r"^#\s+(.+)$", text, re.MULTILINE)
    if m:
        return m.group(1).strip()
    return path.stem


def extract_tags(path: pathlib.Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"^tags:\s*(.+)$", text, re.MULTILINE)
    if m:
        raw = m.group(1).strip()
        tags = [t.strip() for t in raw.split(",") if t.strip()]
        return tags[:5]
    return ["Flutter", "Supabase", "buildinpublic"]


def strip_frontmatter(text: str) -> str:
    """Remove YAML frontmatter block from markdown."""
    if text.startswith("---"):
        end = text.find("---", 3)
        if end != -1:
            return text[end + 3:].lstrip("\n")
    return text


def call_auto_publish(title: str, content: str, tags: list[str], platforms: str) -> dict:
    body = {
        "action": "blog.auto_publish",
        "title": title,
        "content": content,
        "platforms": platforms,
        "tags": tags,
    }
    try:
        resp = requests.post(
            f"{SUPABASE_URL}/functions/v1/schedule-hub",
            headers={
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json",
            },
            json=body,
            timeout=60,
        )
        return resp.json()
    except Exception as e:
        return {"error": str(e)}


def main() -> int:
    if not pathlib.Path(DRAFTS_FILE).exists():
        print("❌ /tmp/drafts.txt not found — run list step first", file=sys.stderr)
        return 1

    drafts = [
        pathlib.Path(line.strip())
        for line in pathlib.Path(DRAFTS_FILE).read_text().splitlines()
        if line.strip()
    ]

    print(f"📋 {len(drafts)} unpublished drafts found")
    if DRY_RUN:
        print("🔍 DRY RUN — listing only, not publishing")

    count = 0
    success = 0
    failed = []

    for draft_path in drafts:
        if count >= MAX_POSTS:
            print(f"ℹ️ MAX_POSTS ({MAX_POSTS}) reached — stopping")
            break

        count += 1
        print(f"\n{'='*60}")
        print(f"[{count}/{len(drafts)}] {draft_path}")

        if not draft_path.exists():
            print(f"  ⚠️ File not found — skipping")
            failed.append(str(draft_path))
            continue

        title = extract_title(draft_path)
        tags = extract_tags(draft_path)

        # Detect language from filename for platform routing
        fname = draft_path.name
        if fname.endswith("-en.md") or "-en-" in fname:
            platforms = "devto"
        elif fname.endswith("-daily-en.md"):
            platforms = "devto"
        else:
            platforms = PLATFORMS

        print(f"  Title: {title}")
        print(f"  Tags:  {', '.join(tags)}")
        print(f"  Platform: {platforms}")

        if DRY_RUN:
            print(f"  [DRY RUN] Would publish → {platforms}")
            continue

        if not SUPABASE_KEY:
            print("  ❌ SUPABASE_KEY not set", file=sys.stderr)
            return 1

        # Read and strip frontmatter from content
        raw_content = draft_path.read_text(encoding="utf-8")
        content = strip_frontmatter(raw_content)

        # Call EF
        result = call_auto_publish(title, content, tags, platforms)
        print(f"  Response: {json.dumps(result, ensure_ascii=False)[:200]}")

        results = result.get("results", {})
        any_ok = False
        for platform, pdata in results.items():
            if isinstance(pdata, dict) and pdata.get("ok"):
                url = pdata.get("url", "")
                print(f"  ✅ {platform}: {url}")
                any_ok = True
            elif isinstance(pdata, dict):
                err = pdata.get("error", pdata.get("body", "unknown"))
                print(f"  ❌ {platform}: {err}")

        if any_ok:
            _mark_published(draft_path)
            success += 1
            print(f"  📝 Marked published: true")
        else:
            failed.append(str(draft_path))
            print(f"  ⚠️ Publish failed — not marking as published")

        if count < len(drafts):
            print(f"  ⏳ Waiting {DELAY}s...")
            time.sleep(DELAY)

    print(f"\n{'='*60}")
    print(f"✅ Complete: {success}/{count} published")
    if failed:
        print(f"❌ Failed ({len(failed)}):")
        for f in failed:
            print(f"  - {f}")

    return 0 if not failed else 1


if __name__ == "__main__":
    sys.exit(main())
