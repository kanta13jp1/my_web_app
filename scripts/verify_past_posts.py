#!/usr/bin/env python3
"""
Verify past Qiita/dev.to posts for factual errors and propose corrections.

Workflow:
1. Fetch list of own articles from each platform
2. For each article, run Claude verification prompt
3. If errors detected, save proposed correction to:
   - blog_corrections table (pending review)
   - docs/blog-corrections/ as markdown for human review
4. Admin manually approves via UI → calls API to PATCH/PUT

Safety: never auto-applies corrections. Always human-in-loop.

Env vars:
- QIITA_ACCESS_TOKEN (read articles + propose)
- DEVTO_API_KEY (read articles + propose)
- ANTHROPIC_API_KEY (verification AI)
- SUPABASE_SERVICE_ROLE_KEY (write proposals)
- DRY_RUN (default true)
- MAX_ARTICLES (default 5; verification is expensive)
"""
from __future__ import annotations

import json
import os
import pathlib
import sys
import time

import requests

QIITA_API = "https://qiita.com/api/v2"
DEVTO_API = "https://dev.to/api"
ANTHROPIC_API = "https://api.anthropic.com/v1/messages"
SUPABASE_REST = os.environ.get(
    "SUPABASE_URL", "https://smmkxxavexumewbfaqpy.supabase.co"
) + "/rest/v1"

MODEL = "claude-haiku-4-5-20251001"
DRY_RUN = os.environ.get("DRY_RUN", "true").lower() == "true"
MAX_ARTICLES = int(os.environ.get("MAX_ARTICLES", "5"))

CORRECTIONS_DIR = pathlib.Path("docs/blog-corrections")


def fetch_qiita_articles(token: str, per_page: int = 100) -> list[dict]:
    r = requests.get(
        f"{QIITA_API}/authenticated_user/items",
        params={"per_page": per_page},
        headers={"Authorization": f"Bearer {token}"},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def fetch_devto_articles(api_key: str, per_page: int = 100) -> list[dict]:
    r = requests.get(
        f"{DEVTO_API}/articles/me/published",
        params={"per_page": per_page},
        headers={"api-key": api_key},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def fetch_devto_article_body(api_key: str, article_id: int) -> str:
    r = requests.get(
        f"{DEVTO_API}/articles/{article_id}",
        headers={"api-key": api_key},
        timeout=30,
    )
    r.raise_for_status()
    return r.json().get("body_markdown", "")


def call_claude_verify(api_key: str, title: str, body: str) -> dict:
    """Returns {has_errors: bool, errors: [{description, correction}], confidence: high|med|low}"""
    snippet = body[:6000]  # avoid huge prompts
    prompt = f"""あなたは技術ブログ校閲者です。以下のブログ記事に**事実誤認・古くなった情報・タイポ**があるかチェックしてください。

## タイトル
{title}

## 本文 (最初の6000文字)
{snippet}

## チェック観点
- API/ライブラリの使い方が古いバージョンのもの
- 数値・統計データの誤り
- 明確な事実誤認 (固有名詞・年号・関係性)
- 重要な技術用語のタイポ

## 注意
- 文体・主観的記述・好みの問題は対象外
- 確実な誤り (high confidence) のみ報告
- 微妙なものは has_errors: false

## 出力 (JSON only)
{{
  "has_errors": true|false,
  "confidence": "high|med|low",
  "errors": [
    {{"location": "該当箇所(20字程度)", "issue": "なぜ誤りか", "correction": "正しい記述"}}
  ]
}}"""
    r = requests.post(
        ANTHROPIC_API,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        json={
            "model": MODEL,
            "max_tokens": 1500,
            "messages": [{"role": "user", "content": prompt}],
        },
        timeout=90,
    )
    r.raise_for_status()
    raw = r.json()["content"][0]["text"].strip()
    if raw.startswith("```"):
        raw = raw.split("```", 2)[1]
        if raw.startswith("json"):
            raw = raw[4:]
        raw = raw.rsplit("```", 1)[0]
    start = raw.find("{")
    end = raw.rfind("}")
    return json.loads(raw[start : end + 1])


def save_correction_proposal(platform: str, article: dict, verification: dict) -> pathlib.Path:
    """Save markdown proposal for human review."""
    CORRECTIONS_DIR.mkdir(parents=True, exist_ok=True)
    aid = article.get("id") or article.get("article_id") or "unknown"
    title = article.get("title", "")
    url = article.get("url") or article.get("canonical_url", "")
    safe_title = "".join(c if c.isalnum() or c in "-_" else "_" for c in title)[:40]
    out = CORRECTIONS_DIR / f"{platform}_{aid}_{safe_title}.md"
    lines = [
        f"# 訂正提案: {title}",
        "",
        f"- **プラットフォーム**: {platform}",
        f"- **記事ID**: {aid}",
        f"- **URL**: {url}",
        f"- **AI confidence**: {verification.get('confidence')}",
        f"- **検出日**: {time.strftime('%Y-%m-%d %H:%M')}",
        "",
        "## 検出された問題",
        "",
    ]
    for i, e in enumerate(verification.get("errors", []), 1):
        lines.append(f"### {i}. {e.get('issue', '')}")
        lines.append(f"- **該当箇所**: `{e.get('location', '')}`")
        lines.append(f"- **訂正案**: {e.get('correction', '')}")
        lines.append("")
    lines.append("---")
    lines.append("**承認方法**: このファイルを確認→管理画面の「訂正承認」ボタンを押すと API 経由で更新")
    lines.append("**却下**: このファイルを削除")
    out.write_text("\n".join(lines), encoding="utf-8")
    return out


def upsert_correction_db(platform: str, article: dict, verification: dict, file_path: str) -> None:
    sb_url = os.environ.get("SUPABASE_URL", "https://smmkxxavexumewbfaqpy.supabase.co")
    sb_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not sb_key:
        print("  ⚠️ SUPABASE_SERVICE_ROLE_KEY missing — skipping DB upsert")
        return
    payload = {
        "platform": platform,
        "article_id": str(article.get("id") or article.get("article_id") or ""),
        "title": article.get("title", ""),
        "url": article.get("url") or article.get("canonical_url", ""),
        "confidence": verification.get("confidence"),
        "errors_json": json.dumps(verification.get("errors", []), ensure_ascii=False),
        "proposal_file": file_path,
        "approved": False,
        "applied_at": None,
    }
    r = requests.post(
        f"{sb_url}/rest/v1/blog_corrections",
        headers={
            "apikey": sb_key,
            "Authorization": f"Bearer {sb_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates",
        },
        json=payload,
        timeout=30,
    )
    if r.status_code >= 400:
        print(f"  ⚠️ DB upsert failed: {r.status_code} {r.text[:200]}")


def main() -> int:
    qiita_token = os.environ.get("QIITA_ACCESS_TOKEN", "")
    devto_key = os.environ.get("DEVTO_API_KEY", "")
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not anthropic_key:
        print("❌ ANTHROPIC_API_KEY required for verification", file=sys.stderr)
        return 2

    proposed = 0
    checked = 0

    # Qiita
    if qiita_token:
        try:
            articles = fetch_qiita_articles(qiita_token)
            print(f"Qiita: {len(articles)} articles fetched")
            for art in articles[:MAX_ARTICLES]:
                checked += 1
                title = art.get("title", "")
                body = art.get("body", "") or art.get("rendered_body", "")
                print(f"  Verifying: {title[:50]}")
                try:
                    v = call_claude_verify(anthropic_key, title, body)
                except Exception as exc:
                    print(f"    ⚠️ verify failed: {exc}")
                    continue
                if v.get("has_errors") and v.get("confidence") == "high":
                    proposed += 1
                    if not DRY_RUN:
                        f = save_correction_proposal("qiita", art, v)
                        upsert_correction_db("qiita", art, v, str(f))
                        print(f"    📝 proposal saved: {f.name}")
                    else:
                        print(f"    [dry-run] would propose {len(v.get('errors',[]))} corrections")
                time.sleep(2)
        except Exception as exc:
            print(f"❌ Qiita batch failed: {exc}", file=sys.stderr)
    else:
        print("ℹ️ QIITA_ACCESS_TOKEN not set — skipping Qiita")

    # dev.to
    if devto_key:
        try:
            articles = fetch_devto_articles(devto_key)
            print(f"dev.to: {len(articles)} articles fetched")
            for art in articles[:MAX_ARTICLES]:
                checked += 1
                title = art.get("title", "")
                body = fetch_devto_article_body(devto_key, art["id"])
                print(f"  Verifying: {title[:50]}")
                try:
                    v = call_claude_verify(anthropic_key, title, body)
                except Exception as exc:
                    print(f"    ⚠️ verify failed: {exc}")
                    continue
                if v.get("has_errors") and v.get("confidence") == "high":
                    proposed += 1
                    if not DRY_RUN:
                        f = save_correction_proposal("devto", art, v)
                        upsert_correction_db("devto", art, v, str(f))
                        print(f"    📝 proposal saved: {f.name}")
                    else:
                        print(f"    [dry-run] would propose {len(v.get('errors',[]))} corrections")
                time.sleep(2)
        except Exception as exc:
            print(f"❌ dev.to batch failed: {exc}", file=sys.stderr)
    else:
        print("ℹ️ DEVTO_API_KEY not set — skipping dev.to")

    print(f"\n✅ Checked {checked} articles, proposed {proposed} corrections")
    print(f"   Mode: {'DRY-RUN' if DRY_RUN else 'LIVE'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
