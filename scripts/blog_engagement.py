#!/usr/bin/env python3
"""
Blog engagement analytics (read-only):
1. Fetch all Qiita/dev.to articles
2. Detect duplicate articles (report-only)
3. Store engagement data (likes/comments/views) in Supabase for app display
4. Store comments/likers in Supabase (fetch + record only)

対他者自動アクション (auto-reply / auto-follow) は恒久廃止 (2026-07-13):
LGTM ユーザーへの無条件自動フォロー + AI 自動コメント返信は
2026-07-12 の Qiita アカウント停止 (ToS 違反) の最有力原因。再実装禁止。
重複記事の自動削除も同時に廃止 (凍結中の書き込み API アクセスは
bot 運用継続の証跡になる) — 検出・報告のみ行う。

Required GitHub secrets:
  QIITA_ACCESS_TOKEN   — Qiita personal access token (停止中は渡さない)
  DEVTO_API_KEY        — dev.to API key (optional)
  SUPABASE_SERVICE_ROLE_KEY
"""
from __future__ import annotations

import os
import sys
import time

import requests

# ── Config ────────────────────────────────────────────────────────
QIITA_TOKEN = os.environ.get("QIITA_ACCESS_TOKEN", "")
DEVTO_KEY = os.environ.get("DEVTO_API_KEY", "")
SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")

DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"

QIITA_BASE = "https://qiita.com/api/v2"
DEVTO_BASE = "https://dev.to/api"


# ── Qiita API helpers ─────────────────────────────────────────────
def qiita_get(path: str) -> list | dict:
    r = requests.get(
        f"{QIITA_BASE}{path}",
        headers={"Authorization": f"Bearer {QIITA_TOKEN}"},
        timeout=15,
    )
    if r.status_code == 200:
        return r.json()
    print(f"  Qiita GET {path} → {r.status_code}: {r.text[:100]}", file=sys.stderr)
    return []


# ── dev.to API helpers ────────────────────────────────────────────
def devto_get(path: str, params: dict | None = None) -> list | dict:
    r = requests.get(
        f"{DEVTO_BASE}{path}",
        headers={"api-key": DEVTO_KEY},
        params=params or {},
        timeout=15,
    )
    if r.status_code == 200:
        return r.json()
    return []


# ── Supabase helpers ──────────────────────────────────────────────
def sb_upsert(table: str, data: dict | list) -> None:
    if DRY_RUN:
        return
    requests.post(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "apikey": SUPABASE_KEY,
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates",
        },
        json=data,
        timeout=15,
    )


# ── Qiita engagement (read-only) ──────────────────────────────────
def process_qiita() -> None:
    if not QIITA_TOKEN:
        print("⚠️ QIITA_ACCESS_TOKEN not set — skipping Qiita", file=sys.stderr)
        return

    print("\n=== Qiita ===")

    # Fetch all articles
    articles: list[dict] = []
    page = 1
    while True:
        batch = qiita_get(f"/authenticated_user/items?page={page}&per_page=100")
        if not isinstance(batch, list) or not batch:
            break
        articles.extend(batch)
        if len(batch) < 100:
            break
        page += 1

    print(f"Found {len(articles)} articles")

    # ── Detect duplicates (report-only / 自動削除は廃止) ─────────
    by_title: dict[str, list[dict]] = {}
    for a in articles:
        by_title.setdefault(a["title"], []).append(a)

    for title, dupes in by_title.items():
        if len(dupes) > 1:
            print(f"  ⚠️ Duplicate ({len(dupes)}x): '{title}' — manual review required")

    # ── Process each article (fetch + record only) ───────────────
    for article in articles:
        article_id = article["id"]
        title = article["title"]
        url = article.get("url", "")
        likes = article.get("likes_count", 0)
        comments_count = article.get("comments_count", 0)
        page_views = article.get("page_views_count", 0)

        print(f"\n  [{article_id[:8]}] {title[:50]}")
        print(f"    likes={likes} comments={comments_count} views={page_views}")

        # Store engagement
        sb_upsert("blog_engagement", {
            "platform": "qiita",
            "article_id": article_id,
            "title": title,
            "url": url,
            "likes_count": likes,
            "comments_count": comments_count,
            "views_count": page_views,
            "updated_at": "now()",
        })

        # ── Comments (record only — auto-reply 恒久廃止) ─────────
        comments = qiita_get(f"/items/{article_id}/comments")
        if not isinstance(comments, list):
            comments = []

        for comment in comments:
            sb_upsert("blog_comments", {
                "platform": "qiita",
                "article_id": article_id,
                "comment_id": comment["id"],
                "author": comment["user"]["id"],
                "body": comment.get("body", ""),
                "created_at": comment.get("created_at", ""),
                "fetched_at": "now()",
            })

        # ── Likers (record only — auto-follow 恒久廃止) ──────────
        likers = qiita_get(f"/items/{article_id}/likes")
        if not isinstance(likers, list):
            likers = []

        for liker in likers:
            user_id = liker.get("user", {}).get("id", "")
            if not user_id:
                continue
            sb_upsert("blog_likers", {
                "article_id": article_id,
                "qiita_user_id": user_id,
                "username": user_id,
                "fetched_at": "now()",
            })

        time.sleep(1)


# ── dev.to engagement (read-only) ─────────────────────────────────
def process_devto() -> None:
    if not DEVTO_KEY:
        print("⚠️ DEVTO_API_KEY not set — skipping dev.to", file=sys.stderr)
        return

    print("\n=== dev.to ===")

    articles = devto_get("/articles/me", {"per_page": 100})
    if not isinstance(articles, list):
        return

    print(f"Found {len(articles)} articles")

    # Detect duplicates by title (report-only)
    by_title: dict[str, list[dict]] = {}
    for a in articles:
        by_title.setdefault(a["title"], []).append(a)

    for title, dupes in by_title.items():
        if len(dupes) > 1:
            print(f"  ⚠️ Duplicate ({len(dupes)}x): '{title}' — manual deletion required (dev.to API limitation)")

    for article in articles:
        article_id = str(article["id"])
        title = article["title"]
        url = article.get("url", "")
        likes = article.get("public_reactions_count", 0)
        comments_count = article.get("comments_count", 0)
        views = article.get("page_views_count", 0)

        print(f"\n  [{article_id}] {title[:50]}")

        sb_upsert("blog_engagement", {
            "platform": "devto",
            "article_id": article_id,
            "title": title,
            "url": url,
            "likes_count": likes,
            "comments_count": comments_count,
            "views_count": views,
            "updated_at": "now()",
        })

        # ── Comments (record only — auto-reply 恒久廃止) ─────────
        comments = devto_get("/comments", {"a_id": article_id})
        if not isinstance(comments, list):
            continue

        for comment in comments:
            sb_upsert("blog_comments", {
                "platform": "devto",
                "article_id": article_id,
                "comment_id": str(comment["id_code"]),
                "author": comment.get("user", {}).get("username", ""),
                "body": comment.get("body_html", comment.get("body_markdown", "")),
                "fetched_at": "now()",
            })

        time.sleep(1)


def main() -> int:
    print("=== Blog Engagement Analytics (read-only) ===")
    if DRY_RUN:
        print("🔍 DRY RUN MODE — no writes will be made")

    if not SUPABASE_KEY:
        print("❌ SUPABASE_SERVICE_ROLE_KEY not set", file=sys.stderr)
        return 1

    process_qiita()
    process_devto()

    print("\n=== Done ===")
    return 0


if __name__ == "__main__":
    sys.exit(main())
