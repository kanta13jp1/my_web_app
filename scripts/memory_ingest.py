#!/usr/bin/env python3
"""memory_ingest.py — AI 第二の脳 Ingest pipeline (Win版#132 part 111 / 2026-05-01).

WBS Issue #974 / SECOND_BRAIN #2 (Autonomous Ingest & Atomic Notes) + INDIE #1 dogfood.

Usage:
  # GitHub Issue を取り込み
  python scripts/memory_ingest.py --gh-issue 1405
  # URL を取り込み
  python scripts/memory_ingest.py --url https://example.com
  # 任意 markdown を取り込み (= stdin)
  cat draft.md | python scripts/memory_ingest.py --slug my-research

Output:
  - memory/ingest_YYYYMMDD_<slug>.md (= Atomic Note 形式)
  - frontmatter: source / ingested_at / type / related links
  - body: original content + metadata

= Obsidian-compat Markdown Vault format. [[link]] 慣習対応.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MEMORY_DIR = Path("C:/Users/kanta/.claude/projects/C--Users-kanta-GitHub-my-web-app/memory")
if not MEMORY_DIR.exists():
    MEMORY_DIR = REPO_ROOT / "memory"

INVALID_FILENAME_CHARS = re.compile(r'[<>:"/\\|?*\x00-\x1f]')


def slugify(text: str, max_len: int = 40) -> str:
    """ファイル名 safe な slug に変換."""
    s = text.strip().lower()
    s = INVALID_FILENAME_CHARS.sub("", s)
    s = re.sub(r"\s+", "-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s[:max_len] or "untitled"


def fetch_github_issue(repo: str, number: int) -> dict[str, str] | None:
    """gh issue view で issue 取得."""
    try:
        r = subprocess.run(
            ["gh", "issue", "view", str(number),
             "--json", "title,body,state,labels,createdAt,updatedAt,url",
             "--repo", repo],
            check=True, capture_output=True, text=True, encoding="utf-8",
        )
        data = json.loads(r.stdout)
        return {
            "title": data.get("title", ""),
            "body": data.get("body", ""),
            "state": data.get("state", ""),
            "labels": ", ".join(l.get("name", "") for l in data.get("labels", [])),
            "createdAt": data.get("createdAt", ""),
            "updatedAt": data.get("updatedAt", ""),
            "url": data.get("url", ""),
        }
    except (subprocess.CalledProcessError, json.JSONDecodeError, FileNotFoundError):
        return None


def fetch_url_content(url: str) -> str | None:
    """簡易 URL fetch (= curl / requests)."""
    try:
        r = subprocess.run(
            ["curl", "-sL", "--max-time", "30",
             "-A", "Mozilla/5.0 (compatible; jibun-memory-ingest/1.0)",
             url],
            check=True, capture_output=True, text=True, encoding="utf-8",
            errors="replace",
        )
        return r.stdout[:50000]  # cap 50KB
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def render_atomic_note(slug: str, source_type: str, source_url: str,
                       title: str, body: str,
                       extra_meta: dict[str, str] | None = None) -> str:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    extra_lines = []
    if extra_meta:
        for k, v in extra_meta.items():
            extra_lines.append(f"  {k}: {v!r}")
    extra_str = "\n".join(extra_lines)

    fm = f"""---
name: {title}
type: ingest
source_type: {source_type}
source_url: {source_url}
slug: {slug}
ingested_at: {now}
{extra_str}
related: []
---
"""
    content = fm + f"\n# {title}\n\n"
    if source_url:
        content += f"> Source: [{source_url}]({source_url})\n\n"
    content += body
    content += "\n\n---\n\n"
    content += "## Atomic Note Conventions\n\n"
    content += "- 双方向 [[link]] で関連 file へ relate\n"
    content += "- type=ingest の file は consolidate-memory --lint で orphan check 対象\n"
    content += "- 詳細: docs/SECOND_BRAIN_PRINCIPLES.md #2 (Autonomous Ingest)\n"
    return content


def write_note(content: str, slug: str, target_dir: Path | None = None) -> Path:
    target = target_dir or MEMORY_DIR
    target.mkdir(parents=True, exist_ok=True)
    date = datetime.now().strftime("%Y%m%d")
    out_path = target / f"ingest_{date}_{slug}.md"
    counter = 1
    while out_path.exists():
        out_path = target / f"ingest_{date}_{slug}_{counter}.md"
        counter += 1
    out_path.write_text(content, encoding="utf-8")
    return out_path


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--gh-issue", type=int, help="GitHub Issue number to ingest")
    p.add_argument("--repo", default="kanta13jp1/my_web_app",
                   help="GitHub repo for --gh-issue")
    p.add_argument("--url", help="URL to fetch and ingest")
    p.add_argument("--slug", default="", help="manual slug override")
    p.add_argument("--target-dir", default="",
                   help="target memory dir (= default to MEMORY_DIR)")
    args = p.parse_args()

    target_dir = Path(args.target_dir) if args.target_dir else None

    if args.gh_issue:
        data = fetch_github_issue(args.repo, args.gh_issue)
        if not data:
            print(f"ERR: failed to fetch issue #{args.gh_issue}", file=sys.stderr)
            return 1
        slug = args.slug or slugify(data["title"])
        title = f"GitHub Issue #{args.gh_issue}: {data['title']}"
        content = render_atomic_note(
            slug=slug,
            source_type="github_issue",
            source_url=data["url"],
            title=title,
            body=data["body"] or "(empty body)",
            extra_meta={
                "gh_issue_number": str(args.gh_issue),
                "gh_issue_state": data["state"],
                "gh_issue_labels": data["labels"],
                "gh_created_at": data["createdAt"],
                "gh_updated_at": data["updatedAt"],
            },
        )
        out = write_note(content, slug, target_dir)
        print(f"wrote {out}")
        return 0

    if args.url:
        body = fetch_url_content(args.url)
        if body is None:
            print(f"ERR: failed to fetch {args.url}", file=sys.stderr)
            return 1
        slug = args.slug or slugify(args.url.split("/")[-1] or "url")
        title = f"URL ingest: {args.url}"
        content = render_atomic_note(
            slug=slug, source_type="url",
            source_url=args.url, title=title, body=body,
        )
        out = write_note(content, slug, target_dir)
        print(f"wrote {out}")
        return 0

    # stdin から読込
    body = sys.stdin.read()
    if not body.strip():
        print("ERR: no input (--gh-issue / --url / stdin から指定)", file=sys.stderr)
        p.print_help()
        return 1
    slug = args.slug or slugify(body[:40] or "stdin")
    title = f"Manual ingest: {slug}"
    content = render_atomic_note(
        slug=slug, source_type="manual",
        source_url="", title=title, body=body,
    )
    out = write_note(content, slug, target_dir)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
