#!/usr/bin/env python3
"""
Qiita 自己返信ループ クリーンアップスクリプト

blog_engagement.py のバグで、bot が自分の返信に対しても再帰的に返信し
無限ループで自己返信を増殖させていた。本スクリプトはその後始末を行う:

1. 全 Qiita 記事のコメントを取得
2. 「連続する自己 (kanta13jp1) コメント」を「自動返信チェーン」と判定
3. チェーンの **最初の 1 件以外** を削除候補として抽出
4. --execute フラグで実際に削除 (デフォルトは dry-run)

使い方:
    # 確認のみ (dry-run)
    QIITA_ACCESS_TOKEN=xxx python3 scripts/cleanup_qiita_self_replies.py

    # 実際に削除
    QIITA_ACCESS_TOKEN=xxx python3 scripts/cleanup_qiita_self_replies.py --execute

    # 特定記事のみ
    QIITA_ACCESS_TOKEN=xxx python3 scripts/cleanup_qiita_self_replies.py \\
        --article cd4ba18c7329700edf80 --execute
"""
from __future__ import annotations

import argparse
import os
import sys
import time

import requests

QIITA_BASE = "https://qiita.com/api/v2"
QIITA_TOKEN = os.environ.get("QIITA_ACCESS_TOKEN", "")
SELF_USER = os.environ.get("SELF_QIITA_USER", "kanta13jp1")
DELAY = float(os.environ.get("DELETE_DELAY", "1.5"))


def qiita_get(path: str) -> list | dict:
    r = requests.get(
        f"{QIITA_BASE}{path}",
        headers={"Authorization": f"Bearer {QIITA_TOKEN}"},
        timeout=30,
    )
    if r.status_code == 200:
        return r.json()
    print(f"  ❌ GET {path}: {r.status_code} {r.text[:200]}", file=sys.stderr)
    return []


def qiita_delete_comment(comment_id: str) -> bool:
    r = requests.delete(
        f"{QIITA_BASE}/comments/{comment_id}",
        headers={"Authorization": f"Bearer {QIITA_TOKEN}"},
        timeout=30,
    )
    return r.status_code == 204


def find_self_reply_chains(comments: list[dict]) -> list[dict]:
    """連続する自己コメントから「最初以外」を返す (削除対象)。

    Qiita コメントは作成日時昇順で返ってくる前提。
    例:
        [user_a] → [self] → [self] → [self] → [user_b] → [self]
        削除対象: 2-3 番目の self (= 自己ループ部分)
    """
    to_delete: list[dict] = []
    self_streak: list[dict] = []

    for c in comments:
        author = c.get("user", {}).get("id", "")
        if author == SELF_USER:
            self_streak.append(c)
        else:
            # Non-self comment breaks the streak
            if len(self_streak) > 1:
                # First self reply is OK, rest are loop spam
                to_delete.extend(self_streak[1:])
            self_streak = []

    # Tail streak (no closing user comment)
    if len(self_streak) > 1:
        to_delete.extend(self_streak[1:])

    return to_delete


def process_article(article: dict, execute: bool) -> tuple[int, int]:
    article_id = article["id"]
    title = article["title"]
    url = article.get("url", "")

    comments = qiita_get(f"/items/{article_id}/comments")
    if not isinstance(comments, list) or not comments:
        return 0, 0

    # Sort by created_at ascending (Qiita returns descending by default sometimes)
    comments.sort(key=lambda c: c.get("created_at", ""))

    self_count = sum(1 for c in comments if c.get("user", {}).get("id") == SELF_USER)
    if self_count == 0:
        return 0, 0

    print(f"\n  [{article_id[:8]}] {title[:50]}")
    print(f"    URL: {url}")
    print(f"    Total comments: {len(comments)} (self: {self_count})")

    to_delete = find_self_reply_chains(comments)
    if not to_delete:
        print(f"    ✅ No self-reply loop detected")
        return 0, 0

    print(f"    🚨 {len(to_delete)} runaway self-replies detected")

    deleted = 0
    for c in to_delete:
        cid = c["id"]
        body_preview = c.get("body", "")[:80].replace("\n", " ")
        created = c.get("created_at", "")[:19]
        print(f"      [{cid[:12]}] {created}  '{body_preview}...'")

        if execute:
            if qiita_delete_comment(cid):
                print(f"      ✅ Deleted")
                deleted += 1
            else:
                print(f"      ❌ Delete failed")
            time.sleep(DELAY)
        else:
            print(f"      [DRY RUN] Would delete")

    return len(to_delete), deleted


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true",
                        help="Actually delete (default: dry-run)")
    parser.add_argument("--article", help="Specific article ID only")
    args = parser.parse_args()

    if not QIITA_TOKEN:
        print("❌ QIITA_ACCESS_TOKEN not set", file=sys.stderr)
        sys.exit(1)

    mode = "🔥 EXECUTE" if args.execute else "📋 DRY RUN"
    print(f"=== Qiita Self-Reply Cleanup ({mode}) ===")
    print(f"Target user: @{SELF_USER}")

    # Fetch articles
    if args.article:
        articles = [{"id": args.article, "title": "(specified article)", "url": ""}]
    else:
        articles = []
        page = 1
        while True:
            batch = qiita_get(f"/authenticated_user/items?page={page}&per_page=100")
            if not isinstance(batch, list) or not batch:
                break
            articles.extend(batch)
            if len(batch) < 100:
                break
            page += 1

    print(f"Processing {len(articles)} article(s)...")

    total_detected = 0
    total_deleted = 0
    for article in articles:
        d, x = process_article(article, args.execute)
        total_detected += d
        total_deleted += x
        time.sleep(0.5)

    print(f"\n=== Summary ===")
    print(f"Total runaway self-replies detected: {total_detected}")
    if args.execute:
        print(f"Total deleted: {total_deleted}")
    else:
        print(f"(Dry run — re-run with --execute to delete)")


if __name__ == "__main__":
    main()
