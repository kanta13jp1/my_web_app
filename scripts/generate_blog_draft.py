#!/usr/bin/env python3
"""
Generate blog draft (Japanese + English) via Anthropic Claude API.

Env vars (all required):
- ANTHROPIC_API_KEY
- TARGET_DATE (YYYY-MM-DD)
- GITLOG_B64 (base64-encoded git log text)
- DRAFT_JA (output path, .md)
- DRAFT_EN (output path, .md)

Design:
- Single API call returns both JA and EN draft as JSON
- Falls back to template if API call fails (we never want a no-post day)
"""
from __future__ import annotations

import base64
import json
import os
import pathlib
import sys
import textwrap

import requests

ANTHROPIC_API = "https://api.anthropic.com/v1/messages"
MODEL = "claude-haiku-4-5-20251001"  # GHA バッチ用途は Haiku 4.5 (低コスト・高速)
MAX_TOKENS = 8000


def call_claude(api_key: str, prompt: str) -> str:
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
        timeout=120,
    )
    resp.raise_for_status()
    data = resp.json()
    return data["content"][0]["text"]


PROMPT_TEMPLATE = """あなたは技術ブロガーです。以下の git log から、2本の技術ブログドラフト (日本語 Qiita用・英語 dev.to用) を生成してください。

## プロジェクト背景
「自分株式会社」— Flutter Web + Supabase で作る、競合21社 (Notion/Evernote/MoneyForward等) 統合のAIライフマネジメントアプリ
本番URL: https://my-web-app-b67f4.web.app/

## 今回の対象日
{target_date}

## 直近の git log (自動commitは除外済)
{gitlog}

## 要件
- **日本語版** (Qiita 向け・カジュアル・#buildinpublic 文化): 800〜1200字
- **英語版** (dev.to 向け・direct/concise): 同じ技術トピックで別ライター風、600〜900 words
- 両方とも frontmatter 形式: title / tags / published: false
- tags は小文字カンマ区切り: Flutter,Supabase,buildinpublic などから3〜4個
- 「はじめに/実装/詰まったポイント/まとめ」の4セクション構成

## 出力形式 (厳守)
JSON で返答してください。他のテキストは一切含めないこと:

```json
{{
  "ja_title": "...",
  "ja_content": "---\\ntitle: ...\\ntags: Flutter,Supabase,buildinpublic,個人開発\\npublished: false\\n---\\n\\n# タイトル\\n\\n...",
  "en_title": "...",
  "en_content": "---\\ntitle: ...\\ntags: Flutter,Supabase,buildinpublic,webdev\\npublished: false\\n---\\n\\n# Title\\n\\n..."
}}
```
"""


def extract_json(text: str) -> dict:
    """Extract JSON from Claude response (may be wrapped in ```json ... ```)"""
    # Try plain JSON first
    text = text.strip()
    if text.startswith("{"):
        return json.loads(text)
    # Try fenced
    if "```json" in text:
        start = text.index("```json") + len("```json")
        end = text.index("```", start)
        return json.loads(text[start:end].strip())
    if "```" in text:
        start = text.index("```") + 3
        end = text.index("```", start)
        return json.loads(text[start:end].strip())
    raise ValueError(f"Could not extract JSON from:\n{text[:500]}")


def fallback_template(target_date: str, gitlog: str) -> tuple[str, str]:
    """Generate a minimal template draft when API fails — never skip a day."""
    ja = textwrap.dedent(f"""\
        ---
        title: "自分株式会社 開発日誌 {target_date}"
        tags: Flutter,Supabase,buildinpublic,個人開発
        published: false
        ---

        # 自分株式会社 開発日誌 {target_date}

        ## 今日の進捗

        {gitlog}

        ## 所感

        引き続き Flutter Web + Supabase + AI 統合を進めている。

        ---
        自分株式会社: https://my-web-app-b67f4.web.app/
        #FlutterWeb #Supabase #buildinpublic #個人開発
    """)
    en = textwrap.dedent(f"""\
        ---
        title: "Jibun Inc. Dev Log {target_date}"
        tags: Flutter,Supabase,buildinpublic,webdev
        published: false
        ---

        # Jibun Inc. Dev Log {target_date}

        ## Progress

        {gitlog}

        ## Reflection

        Keeping the Flutter Web + Supabase + AI integration moving forward.

        ---
        Building in public: https://my-web-app-b67f4.web.app/
        #FlutterWeb #Supabase #buildinpublic
    """)
    return ja, en


def main() -> int:
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")
    target_date = os.environ["TARGET_DATE"]
    gitlog_b64 = os.environ["GITLOG_B64"]
    draft_ja = pathlib.Path(os.environ["DRAFT_JA"])
    draft_en = pathlib.Path(os.environ["DRAFT_EN"])

    gitlog = base64.b64decode(gitlog_b64).decode("utf-8")
    if not gitlog.strip():
        print("❌ No git log provided", file=sys.stderr)
        return 1

    draft_ja.parent.mkdir(parents=True, exist_ok=True)

    if not api_key:
        print("⚠️ ANTHROPIC_API_KEY not set — using template fallback", file=sys.stderr)
        ja_content, en_content = fallback_template(target_date, gitlog)
    else:
        prompt = PROMPT_TEMPLATE.format(target_date=target_date, gitlog=gitlog)
        try:
            print("Calling Anthropic API...", flush=True)
            raw = call_claude(api_key, prompt)
            parsed = extract_json(raw)
            ja_content = parsed["ja_content"]
            en_content = parsed["en_content"]
            print(f"✅ API generated JA={len(ja_content)} chars, EN={len(en_content)} chars", flush=True)
        except Exception as exc:  # noqa: BLE001 - never skip a day
            print(f"⚠️ API failed: {exc} — using template fallback", file=sys.stderr)
            ja_content, en_content = fallback_template(target_date, gitlog)

    draft_ja.write_text(ja_content, encoding="utf-8")
    draft_en.write_text(en_content, encoding="utf-8")
    print(f"✅ Wrote {draft_ja} and {draft_en}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
