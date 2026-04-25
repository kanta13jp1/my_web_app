#!/usr/bin/env python3
"""
Generate weekly SNS draft (X / Zenn) via AI API with multi-model fallback.

Provider chain (quota-resilient):
  1. Anthropic Claude Haiku (primary — low cost, fast)
  2. Google Gemini Flash (fallback — free tier, triggered on 429/529)
  3. Template (last resort)

Env vars:
- ANTHROPIC_API_KEY  (optional)
- GEMINI_API_KEY     (optional)
- TARGET_DATE        (YYYY-MM-DD — week end date)
- WEEK_START         (YYYY-MM-DD — week start date)
- OUTFILE            (output path, .md)
- GITLOG_B64         (base64-encoded git log text)
- REPORTS_B64        (base64-encoded daily reports text, optional)
"""
from __future__ import annotations

import base64
import json
import os
import pathlib
import sys
from datetime import datetime, timedelta

import requests

ANTHROPIC_API = "https://api.anthropic.com/v1/messages"
GEMINI_API = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"
CLAUDE_MODEL = "claude-haiku-4-5-20251001"
MAX_TOKENS = 4000
QUOTA_ERRORS = {429, 529}


class QuotaExceededError(Exception):
    pass


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
        raise QuotaExceededError(f"Claude quota: HTTP {resp.status_code}")
    resp.raise_for_status()
    return resp.json()["content"][0]["text"]


def call_gemini(api_key: str, prompt: str) -> str:
    resp = requests.post(
        f"{GEMINI_API}?key={api_key}",
        headers={"content-type": "application/json"},
        json={"contents": [{"parts": [{"text": prompt}]}]},
        timeout=120,
    )
    if resp.status_code in QUOTA_ERRORS:
        raise QuotaExceededError(f"Gemini quota: HTTP {resp.status_code}")
    resp.raise_for_status()
    return resp.json()["candidates"][0]["content"]["parts"][0]["text"]


PROMPT_TEMPLATE = """あなたは「自分株式会社」プロダクトのSNSマネージャーです。
以下の情報をもとに、今週の週次SNSドラフトを生成してください。

## プロジェクト背景
「自分株式会社」— Flutter Web + Supabase で作る、競合21社 (Notion/Evernote/MoneyForward/Slack等) 統合のAIライフマネジメントアプリ。
本番URL: https://my-web-app-b67f4.web.app/
理念: 「あなた自身のCEO」として意思決定・資産管理・KPI管理を一元化。

## 今週のコミットログ ({week_start} 〜 {target_date})
{git_log}

{daily_reports_section}

## 出力フォーマット (Markdown)
以下のフォーマットで正確に出力してください:

# 週次 SNS 投稿ドラフト ({week_start} 〜 {target_date} 週)

> 生成: Claude Schedule (weekly-sns-draft) · {target_date}
> データソース: docs/daily-reports/{week_start}〜{target_date}

---

## 今週のハイライト

| # | 実績 | 詳細 |
|---|------|------|
(コミットログから主要な実績を最大10件。具体的な数値や社数を含める)

---

## X (Twitter) 投稿ドラフト (140字以内)

### ドラフト1: 主要実績フォーカス
```
(140字以内のXポスト。数値・絵文字・URL・ハッシュタグ含む)
```
(X字)

### ドラフト2: 機能開発の進捗
```
(140字以内のXポスト。✅リスト形式・絵文字・URL・ハッシュタグ含む)
```
(X字)

---

## Zenn 記事ネタ提案

1. **「タイトル」**
   - 内容の要点と技術的ポイント
   - 対象読者
   - 推定 PV: 高/中/低

2. **「タイトル」**
   - ...

3. **「タイトル」**
   - ...

---

## 今週の開発サマリー (コミット活動)

(日付別の主要活動を箇条書きで。ユーザー数・T-1ブログ弾数など数値があれば含める)

---

## Philosophy Alignment サマリー

今週の作業は PHILOSOPHY 9原則に対して平均 **X.X/9** の整合性を達成。
(主要な実績と対応する原則を3〜5件)
"""


def make_template(target_date: str, week_start: str, git_log: str) -> str:
    highlights = []
    for i, line in enumerate(git_log.strip().split("\n")[:10], 1):
        title = line.lstrip("- ").strip()
        if title:
            highlights.append(f"| {i} | **{title[:40]}** | — |")
    highlights_md = "\n".join(highlights) if highlights else "| 1 | 開発継続中 | — |"

    return f"""# 週次 SNS 投稿ドラフト ({week_start} 〜 {target_date} 週)

> 生成: Claude Schedule (weekly-sns-draft) · {target_date} [template fallback]
> データソース: docs/daily-reports/{week_start}〜{target_date}

---

## 今週のハイライト

| # | 実績 | 詳細 |
|---|------|------|
{highlights_md}

---

## X (Twitter) 投稿ドラフト (140字以内)

### ドラフト1: 主要実績フォーカス
```
自分株式会社、今週もビルド継続中🚀
AIライフマネジメントアプリ開発進捗更新。
21競合超えオールインワン → https://my-web-app-b67f4.web.app/ #buildinpublic #FlutterWeb
```

### ドラフト2: 機能開発の進捗
```
今週の実装📦
コツコツ積み上げ中💪
https://my-web-app-b67f4.web.app/ #buildinpublic #Supabase
```

---

## Zenn 記事ネタ提案

1. **「自分株式会社の週次開発レポート」**
   - 今週の実装内容まとめ
   - 対象読者: Flutter/Supabase 個人開発者
   - 推定 PV: 中

---

## 今週の開発サマリー

- 開発継続中

---

## Philosophy Alignment サマリー

今週の作業は PHILOSOPHY 9原則に対して継続的な取り組みを実施。
"""


def main() -> None:
    target_date = os.environ.get("TARGET_DATE", "")
    week_start = os.environ.get("WEEK_START", "")
    outfile = os.environ.get("OUTFILE", "")
    gitlog_b64 = os.environ.get("GITLOG_B64", "")
    reports_b64 = os.environ.get("REPORTS_B64", "")

    if not outfile:
        print("ERROR: OUTFILE not set", file=sys.stderr)
        sys.exit(1)

    git_log = base64.b64decode(gitlog_b64).decode("utf-8") if gitlog_b64 else "(no commits)"
    daily_reports = base64.b64decode(reports_b64).decode("utf-8") if reports_b64 else ""

    daily_reports_section = ""
    if daily_reports:
        daily_reports_section = f"## 日次レポートサマリー (直近7日)\n{daily_reports[:3000]}"

    prompt = PROMPT_TEMPLATE.format(
        target_date=target_date,
        week_start=week_start,
        git_log=git_log[:2000],
        daily_reports_section=daily_reports_section,
    )

    anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "")
    gemini_key = os.environ.get("GEMINI_API_KEY", "")

    content = None

    if anthropic_key:
        try:
            print("Trying Claude Haiku...")
            content = call_claude(anthropic_key, prompt)
            print("Claude Haiku: success")
        except QuotaExceededError as e:
            print(f"Claude quota exceeded: {e}")
        except Exception as e:
            print(f"Claude error: {e}")

    if content is None and gemini_key:
        try:
            print("Trying Gemini Flash...")
            content = call_gemini(gemini_key, prompt)
            print("Gemini Flash: success")
        except QuotaExceededError as e:
            print(f"Gemini quota exceeded: {e}")
        except Exception as e:
            print(f"Gemini error: {e}")

    if content is None:
        print("Falling back to template")
        content = make_template(target_date, week_start, git_log)

    out = pathlib.Path(outfile)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(content, encoding="utf-8")
    print(f"Written: {outfile}")
    print(f"Size: {len(content)} chars")


if __name__ == "__main__":
    main()
