#!/usr/bin/env python3
"""
Blog engagement automation:
1. Fetch all Qiita/dev.to articles
2. Detect & delete duplicate articles
3. Auto-reply to unanswered comments (via Claude Haiku)
4. Auto-follow users who liked (Qiita only)
5. Store engagement data in Supabase for app display

Required GitHub secrets:
  QIITA_ACCESS_TOKEN   — Qiita personal access token
  DEVTO_API_KEY        — dev.to API key (optional)
  SUPABASE_SERVICE_ROLE_KEY
  ANTHROPIC_API_KEY    — for generating replies (optional, uses template fallback)
"""
from __future__ import annotations

import os
import sys
import time
import json

import requests

# ── Config ────────────────────────────────────────────────────────
QIITA_TOKEN = os.environ.get("QIITA_ACCESS_TOKEN", "")
DEVTO_KEY = os.environ.get("DEVTO_API_KEY", "")
SUPABASE_URL = "https://smmkxxavexumewbfaqpy.supabase.co"
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
ANTHROPIC_KEY = os.environ.get("ANTHROPIC_API_KEY", "")

DRY_RUN = os.environ.get("DRY_RUN", "false").lower() == "true"
REPLY_DELAY = 3   # seconds between API calls
FOLLOW_DELAY = 2

# 自分自身のコメントには返信しない (記事オーナー)
SKIP_AUTHORS = {"kanta13jp1"}

QIITA_BASE = "https://qiita.com/api/v2"
DEVTO_BASE = "https://dev.to/api"

REPLY_PROMPT = """\
あなたは「自分株式会社」というFlutter Web + Supabase + AIのライフ管理アプリを個人開発している日本人エンジニアです。
Qiitaの記事「{title}」に{author}さんからコメントが届きました:

---
{body}
---

このコメントへの返信を、200文字以内の日本語で書いてください。
- 感謝の言葉を一言入れる
- コメントの内容に具体的に反応する
- 技術的な補足があれば短く追記する
URLや過度な絵文字は使わないこと。"""


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


def qiita_post(path: str, body: dict) -> requests.Response:
    return requests.post(
        f"{QIITA_BASE}{path}",
        headers={"Authorization": f"Bearer {QIITA_TOKEN}", "Content-Type": "application/json"},
        json=body,
        timeout=15,
    )


def qiita_delete(path: str) -> requests.Response:
    return requests.delete(
        f"{QIITA_BASE}{path}",
        headers={"Authorization": f"Bearer {QIITA_TOKEN}"},
        timeout=15,
    )


def qiita_put(path: str) -> requests.Response:
    return requests.put(
        f"{QIITA_BASE}{path}",
        headers={"Authorization": f"Bearer {QIITA_TOKEN}"},
        timeout=15,
    )


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


def devto_post(path: str, body: dict) -> requests.Response:
    return requests.post(
        f"{DEVTO_BASE}{path}",
        headers={"api-key": DEVTO_KEY, "Content-Type": "application/json"},
        json=body,
        timeout=15,
    )


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


def sb_check(table: str, filters: dict) -> list:
    params = {k: v for k, v in filters.items()}
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{table}",
        headers={"Authorization": f"Bearer {SUPABASE_KEY}", "apikey": SUPABASE_KEY},
        params=params,
        timeout=15,
    )
    if r.status_code == 200:
        return r.json()
    return []


# ── AI reply generation ───────────────────────────────────────────
def generate_reply(title: str, body: str, author: str) -> str:
    if not ANTHROPIC_KEY:
        return f"コメントありがとうございます！参考になれば嬉しいです 😊"

    try:
        resp = requests.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": ANTHROPIC_KEY,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": "claude-haiku-4-5-20251001",
                "max_tokens": 250,
                "messages": [
                    {
                        "role": "user",
                        "content": REPLY_PROMPT.format(
                            title=title, author=author, body=body
                        ),
                    }
                ],
            },
            timeout=30,
        )
        if resp.status_code == 200:
            return resp.json()["content"][0]["text"].strip()
    except Exception as e:
        print(f"  ⚠️ Claude API error: {e}", file=sys.stderr)

    return f"{author}さん、コメントありがとうございます！参考になれば嬉しいです。"


# ── Qiita engagement ──────────────────────────────────────────────
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

    # ── Detect and delete duplicates ────────────────────────────
    by_title: dict[str, list[dict]] = {}
    for a in articles:
        by_title.setdefault(a["title"], []).append(a)

    dedup_count = 0
    for title, dupes in by_title.items():
        if len(dupes) <= 1:
            continue
        dupes.sort(key=lambda x: x["created_at"])
        print(f"  ⚠️ Duplicate ({len(dupes)}x): '{title}'")
        for old in dupes[:-1]:
            print(f"    Deleting old: {old['id']} ({old['created_at'][:10]})")
            if not DRY_RUN:
                r = qiita_delete(f"/items/{old['id']}")
                if r.status_code == 204:
                    print(f"    ✅ Deleted")
                    dedup_count += 1
                else:
                    print(f"    ❌ Failed: {r.status_code}")
                time.sleep(1)
            else:
                print(f"    [DRY RUN] Would delete")

    if dedup_count > 0:
        print(f"  Deleted {dedup_count} duplicate articles")

    # ── Process each article ─────────────────────────────────────
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

        # ── Comments + auto-reply ────────────────────────────────
        comments = qiita_get(f"/items/{article_id}/comments")
        if not isinstance(comments, list):
            comments = []

        for comment in comments:
            comment_id = comment["id"]
            author = comment["user"]["id"]
            body = comment.get("body", "")
            created_at = comment.get("created_at", "")

            # 自分自身のコメントはスキップ
            if author in SKIP_AUTHORS:
                print(f"    ⏭️  Skipping own comment @{author}")
                continue

            # Check if already replied
            existing = sb_check(
                "blog_comments",
                {"platform": "eq.qiita", "comment_id": f"eq.{comment_id}", "replied": "eq.true"},
            )

            if not existing:
                print(f"    💬 Replying to @{author}...")
                reply_text = generate_reply(title, body, author)

                replied = False
                if not DRY_RUN:
                    r = qiita_post(f"/items/{article_id}/comments", {"body": reply_text})
                    replied = r.status_code in [200, 201]
                    if not replied:
                        print(f"    ❌ Reply failed: {r.status_code} {r.text[:100]}")
                    time.sleep(REPLY_DELAY)

                sb_upsert("blog_comments", {
                    "platform": "qiita",
                    "article_id": article_id,
                    "comment_id": comment_id,
                    "author": author,
                    "body": body,
                    "created_at": created_at,
                    "replied": replied or DRY_RUN,
                    "reply_text": reply_text,
                    "replied_at": "now()" if (replied or DRY_RUN) else None,
                    "fetched_at": "now()",
                })
                print(f"    {'[DRY RUN] ' if DRY_RUN else ''}✅ Replied")
            else:
                # Update fetched_at
                sb_upsert("blog_comments", {
                    "platform": "qiita",
                    "article_id": article_id,
                    "comment_id": comment_id,
                    "author": author,
                    "body": body,
                    "created_at": created_at,
                    "fetched_at": "now()",
                })

        # ── Likers + auto-follow ─────────────────────────────────
        likers = qiita_get(f"/items/{article_id}/likes")
        if not isinstance(likers, list):
            likers = []

        for liker in likers:
            user_data = liker.get("user", {})
            user_id = user_data.get("id", "")
            if not user_id:
                continue

            existing = sb_check(
                "blog_likers",
                {"article_id": f"eq.{article_id}", "qiita_user_id": f"eq.{user_id}", "followed": "eq.true"},
            )

            if not existing:
                print(f"    ❤️  Following new liker @{user_id}...")
                followed = False
                if not DRY_RUN:
                    r = qiita_put(f"/users/{user_id}/following")
                    followed = r.status_code in [200, 204]
                    time.sleep(FOLLOW_DELAY)

                sb_upsert("blog_likers", {
                    "article_id": article_id,
                    "qiita_user_id": user_id,
                    "username": user_id,
                    "followed": followed or DRY_RUN,
                    "followed_at": "now()" if (followed or DRY_RUN) else None,
                    "fetched_at": "now()",
                })
                print(f"    {'[DRY RUN] ' if DRY_RUN else ''}✅ Followed")
            else:
                sb_upsert("blog_likers", {
                    "article_id": article_id,
                    "qiita_user_id": user_id,
                    "username": user_id,
                    "fetched_at": "now()",
                })

        time.sleep(1)


# ── dev.to engagement ─────────────────────────────────────────────
def process_devto() -> None:
    if not DEVTO_KEY:
        print("⚠️ DEVTO_API_KEY not set — skipping dev.to", file=sys.stderr)
        return

    print("\n=== dev.to ===")

    articles = devto_get("/articles/me", {"per_page": 100})
    if not isinstance(articles, list):
        return

    print(f"Found {len(articles)} articles")

    # Detect duplicates by title
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

        # Fetch comments
        comments = devto_get("/comments", {"a_id": article_id})
        if not isinstance(comments, list):
            continue

        for comment in comments:
            comment_id = str(comment["id_code"])
            author = comment.get("user", {}).get("username", "")
            body = comment.get("body_html", comment.get("body_markdown", ""))

            # 自分自身のコメントはスキップ
            if author in SKIP_AUTHORS or author == "kanta13jp1":
                print(f"    ⏭️  Skipping own comment @{author}")
                continue

            existing = sb_check(
                "blog_comments",
                {"platform": "eq.devto", "comment_id": f"eq.{comment_id}", "replied": "eq.true"},
            )

            if not existing:
                print(f"    💬 Replying to @{author} (dev.to)...")
                reply_text = generate_reply(title, body, author)
                replied = False

                if not DRY_RUN:
                    r = devto_post("/comments", {
                        "comment": {
                            "body_markdown": reply_text,
                            "commentable_id": article_id,
                            "commentable_type": "Article",
                            "parent_id": comment.get("id_code"),
                        }
                    })
                    replied = r.status_code in [200, 201]
                    time.sleep(REPLY_DELAY)

                sb_upsert("blog_comments", {
                    "platform": "devto",
                    "article_id": article_id,
                    "comment_id": comment_id,
                    "author": author,
                    "body": body,
                    "replied": replied or DRY_RUN,
                    "reply_text": reply_text,
                    "replied_at": "now()" if (replied or DRY_RUN) else None,
                    "fetched_at": "now()",
                })

        time.sleep(1)


def main() -> int:
    print("=== Blog Engagement Automation ===")
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
