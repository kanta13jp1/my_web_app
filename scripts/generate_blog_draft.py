#!/usr/bin/env python3
"""
Generate blog draft (Japanese + English) via AI API with multi-model fallback.

Provider chain (quota-resilient):
  1. Anthropic Claude Haiku (primary — low cost, fast)
  2. Google Gemini Flash (fallback — free tier, triggered on 429/529)
  3. Template (last resort — never skip a day)

Env vars:
- ANTHROPIC_API_KEY  (optional — skips to Gemini if absent)
- GOOGLE_AI_API_KEY  (optional — skips to template if absent)
- TARGET_DATE (YYYY-MM-DD)
- GITLOG_B64 (base64-encoded git log text)
- DRAFT_JA (output path, .md)
- DRAFT_EN (output path, .md)
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
GEMINI_API = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
CLAUDE_MODEL = "claude-haiku-4-5-20251001"
MAX_TOKENS = 8000

QUOTA_ERRORS = {429, 529}  # rate limit / quota exhausted


def call_claude(api_key: str, prompt: str) -> str:
    resp = requests.post(
        ANTHROPIC_API,
        headers={
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        json={
            "model": CLAUDE_MODEL,
            "max_tokens": MAX_TOKENS,
            "messages": [{"role": "user", "content": prompt}],
        },
        timeout=120,
    )
    if resp.status_code in QUOTA_ERRORS:
        raise QuotaExceededError(f"Claude quota/rate-limit: HTTP {resp.status_code}")
    resp.raise_for_status()
    data = resp.json()
    return data["content"][0]["text"]


def call_gemini(api_key: str, prompt: str) -> str:
    resp = requests.post(
        f"{GEMINI_API}?key={api_key}",
        headers={"content-type": "application/json"},
        json={"contents": [{"parts": [{"text": prompt}]}]},
        timeout=120,
    )
    if resp.status_code in QUOTA_ERRORS:
        raise QuotaExceededError(f"Gemini quota/rate-limit: HTTP {resp.status_code}")
    resp.raise_for_status()
    data = resp.json()
    return data["candidates"][0]["content"]["parts"][0]["text"]


class QuotaExceededError(Exception):
    pass


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
    """Extract JSON from AI response (may be wrapped in ```json ... ```)"""
    text = text.strip()
    if text.startswith("{"):
        return json.loads(text)
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
    """Last-resort template — never skip a day."""
    ja = textwrap.dedent("""\
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
    """).format(target_date=target_date, gitlog=gitlog)
    en = textwrap.dedent("""\
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
    """).format(target_date=target_date, gitlog=gitlog)
    return ja, en


def generate_with_ai(prompt: str, anthropic_key: str, gemini_key: str) -> tuple[str, str, str]:
    """Try Claude → Gemini → template. Returns (ja, en, provider_used)."""
    # 1. Claude (primary)
    if anthropic_key:
        try:
            print("Calling Anthropic Claude API...", flush=True)
            raw = call_claude(anthropic_key, prompt)
            parsed = extract_json(raw)
            print(f"✅ Claude: JA={len(parsed['ja_content'])} chars, EN={len(parsed['en_content'])} chars")
            return parsed["ja_content"], parsed["en_content"], "claude"
        except QuotaExceededError as e:
            print(f"⚠️ {e} — falling back to Gemini", file=sys.stderr)
        except Exception as e:
            print(f"⚠️ Claude failed: {e} — falling back to Gemini", file=sys.stderr)
    else:
        print("⚠️ ANTHROPIC_API_KEY not set — trying Gemini", file=sys.stderr)

    # 2. Gemini Flash (fallback)
    if gemini_key:
        try:
            print("Calling Google Gemini Flash API...", flush=True)
            raw = call_gemini(gemini_key, prompt)
            parsed = extract_json(raw)
            print(f"✅ Gemini: JA={len(parsed['ja_content'])} chars, EN={len(parsed['en_content'])} chars")
            return parsed["ja_content"], parsed["en_content"], "gemini"
        except QuotaExceededError as e:
            print(f"⚠️ {e} — falling back to template", file=sys.stderr)
        except Exception as e:
            print(f"⚠️ Gemini failed: {e} — falling back to template", file=sys.stderr)
    else:
        print("⚠️ GOOGLE_AI_API_KEY not set — using template", file=sys.stderr)

    # 3. Template (last resort)
    return None, None, "template"


def main() -> int:
    anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "")
    gemini_key = os.environ.get("GEMINI_API_KEY", "")
    target_date = os.environ["TARGET_DATE"]
    gitlog_b64 = os.environ["GITLOG_B64"]
    draft_ja = pathlib.Path(os.environ["DRAFT_JA"])
    draft_en = pathlib.Path(os.environ["DRAFT_EN"])

    gitlog = base64.b64decode(gitlog_b64).decode("utf-8")
    if not gitlog.strip():
        print("❌ No git log provided", file=sys.stderr)
        return 1

    draft_ja.parent.mkdir(parents=True, exist_ok=True)
    prompt = PROMPT_TEMPLATE.format(target_date=target_date, gitlog=gitlog)

    ja_content, en_content, provider = generate_with_ai(prompt, anthropic_key, gemini_key)

    if provider == "template":
        print("⚠️ All AI providers failed — using static template", file=sys.stderr)
        ja_content, en_content = fallback_template(target_date, gitlog)

    draft_ja.write_text(ja_content, encoding="utf-8")
    draft_en.write_text(en_content, encoding="utf-8")
    print(f"✅ [{provider}] Wrote {draft_ja} and {draft_en}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
