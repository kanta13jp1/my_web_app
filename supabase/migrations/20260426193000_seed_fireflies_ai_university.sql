-- PS#3 S61: AI大学 216→217社化 — Fireflies.ai 追加
-- Fireflies.ai: AI会議アシスタント / 自動文字起こし+要約+Action Items / Slack/CRM統合 / API提供

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'fireflies-ai',
  'overview',
  'Fireflies.ai — AI会議アシスタント (自動文字起こし+要約+Action Items / Slack/CRM連携 / API)',
  $$## Fireflies.ai — AI会議アシスタント

**カテゴリ**: AI Meeting Assistant / Transcription / Workflow Automation
**設立**: 2016年 / 本社: San Francisco, CA / 資金調達: ~$19M (Series A)
**特徴**: 会議を自動録音・文字起こし・要約・Action Items 抽出し、CRM/Slack/Notion に自動同期
**ユーザー**: セールスチーム / スタートアップ / コンサルタント / リモートチーム
**評価**: 8/9

### 概要
Fireflies.ai は**会議の全プロセスを AI で自動化するプラットフォーム**。Google Meet / Zoom / Microsoft Teams / Webex など主要ビデオ会議に「Fred」というボットとして参加し、リアルタイムで文字起こしを行う。会議終了後は AI が自動的に要約・Action Items・決定事項・キーフレーズを抽出し、Slack / HubSpot / Salesforce / Notion などに自動同期する。Otter.ai が個人向け文字起こしに強いのに対し、Fireflies はチームワークフロー・CRM 統合・セールス分析に特化している。

### 主な特長
- **自動会議参加 (Fred Bot)**: カレンダーと連携してミーティングに Fred が自動参加 → ゼロクリック録音
- **リアルタイム文字起こし**: 100+ 言語対応 / 話者識別 / タイムスタンプ付き
- **AI 要約 & Smart Summary**: 会議の概要・決定事項・Action Items・フォローアップを自動生成
- **Action Items 追跡**: タスクを自動抽出 → Asana / ClickUp / Jira に自動作成
- **Soundbite**: 会議の重要部分を 1 クリックでクリップ化して共有
- **会議内検索**: 過去全会議を横断検索 (「先月の予算会議で決めたことは?」)
- **セールス分析**: トーク比率 / モノローグ検出 / センチメント分析 / キーワードトラッカー
- **CRM 自動同期**: 通話後に HubSpot / Salesforce / Pipedrive の Deal に自動メモ追加
- **Fireflies API**: 録音・文字起こし・要約の全データにプログラムアクセス

### 統合対応ビデオ会議
Google Meet / Zoom / Microsoft Teams / Webex / Ringcentral /
GoToMeeting / UberConference / BlueJeans / 電話通話 (Dialpad/Aircall)

### Otter.ai との比較
| 機能 | Fireflies.ai | Otter.ai |
|------|------------|---------|
| 自動ボット参加 | ✅ Fred Bot | ✅ OtterPilot |
| 話者識別 | ✅ | ✅ |
| Action Items | ✅ 自動抽出+CRM連携 | △ 手動タグ |
| CRM統合 | ✅ HubSpot/Salesforce/Pipedrive | ❌ |
| セールス分析 | ✅ トーク比率/センチメント | ❌ |
| API | ✅ GraphQL | ✅ REST |
| 無料プラン | ✅ (800分/月) | ✅ (300分/月) |
- Fireflies: チーム × セールス × CRM 特化
- Otter: 個人 × 文字起こし精度 × リアルタイム閲覧

### 導入コスト
- **Free**: 月 800 分文字起こし / ストレージ 3ヶ月
- **Pro**: 月 $10/ユーザー / 無制限文字起こし / AI 要約 / CRM 統合
- **Business**: 月 $19/ユーザー / 動画録画 / 会議分析 / 優先サポート
- **Enterprise**: カスタム / SSO / HIPAA / カスタム AI モデル$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'fireflies-ai',
  'api',
  'Fireflies.ai API — GraphQL API で会議データ取得・Action Items 抽出・CRM 自動化 (Python)',
  $$## Fireflies.ai API (GraphQL)

### セットアップ
```bash
# https://app.fireflies.ai/integrations/custom/fireflies でAPIキー取得
pip install requests
export FIREFLIES_API_KEY="your_api_key_here"
```

### 会議一覧取得
```python
import requests
import os

FIREFLIES_API_KEY = os.environ["FIREFLIES_API_KEY"]
GRAPHQL_URL = "https://api.fireflies.ai/graphql"

def graphql_request(query: str, variables: dict = None) -> dict:
    headers = {
        "Authorization": f"Bearer {FIREFLIES_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {"query": query, "variables": variables or {}}
    resp = requests.post(GRAPHQL_URL, json=payload, headers=headers)
    resp.raise_for_status()
    return resp.json()

# 最近の会議一覧
LIST_TRANSCRIPTS = """
query GetTranscripts($limit: Int) {
  transcripts(limit: $limit) {
    id
    title
    date
    duration
    participants
    summary {
      overview
      action_items
      keywords
    }
  }
}
"""
result = graphql_request(LIST_TRANSCRIPTS, {"limit": 10})
for t in result["data"]["transcripts"]:
    print(f"{t['title']} ({t['duration']}s)")
    if t["summary"]:
        print(f"  概要: {t['summary']['overview'][:100]}")
```

### 特定会議の詳細 + Action Items 取得
```python
GET_TRANSCRIPT = """
query GetTranscript($id: String!) {
  transcript(id: $id) {
    id
    title
    date
    participants
    sentences {
      index
      speaker_name
      text
      start_time
      end_time
    }
    summary {
      overview
      action_items
      keywords
      outline
      shorthand_bullet
    }
    meeting_attendees {
      displayName
      email
      phoneNumber
    }
  }
}
"""

def get_meeting_details(transcript_id: str) -> dict:
    result = graphql_request(GET_TRANSCRIPT, {"id": transcript_id})
    return result["data"]["transcript"]

# 会議詳細取得
meeting = get_meeting_details("transcript_id_here")
print(f"参加者: {', '.join(meeting['participants'])}")
print(f"\nAction Items:")
for item in meeting["summary"]["action_items"]:
    print(f"  - {item}")
```

### 会議検索 (全会議横断)
```python
SEARCH_TRANSCRIPTS = """
query SearchTranscripts($query: String!) {
  transcripts(title: $query) {
    id
    title
    date
    summary {
      overview
    }
  }
}
"""

def search_meetings(keyword: str) -> list:
    result = graphql_request(SEARCH_TRANSCRIPTS, {"query": keyword})
    return result["data"]["transcripts"]

# 「予算」を含む会議を全検索
budget_meetings = search_meetings("予算")
for m in budget_meetings:
    print(f"{m['date']}: {m['title']}")
```

### CRM 自動同期 (Webhook + HubSpot)
```python
# Webhook: 会議終了後に Fireflies が POST を送信
# Flask/FastAPI エンドポイント例

from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/webhook/fireflies", methods=["POST"])
def handle_meeting_complete():
    data = request.json
    transcript_id = data.get("transcriptId")

    # 会議詳細取得
    meeting = get_meeting_details(transcript_id)
    action_items = meeting["summary"]["action_items"]

    # HubSpot に自動メモ追加
    hubspot_note = "\n".join([f"• {item}" for item in action_items])
    # add_hubspot_note(deal_id, hubspot_note)  # HubSpot API 呼び出し

    return jsonify({"status": "ok", "action_items_count": len(action_items)})
```

### GHA 自動ワークフロー (週次会議サマリーレポート)
```yaml
# .github/workflows/weekly-meeting-report.yml
# 毎週金曜 18:00 JST → Fireflies API → docs/meeting-reports/ に保存
steps:
  - name: Generate weekly meeting report
    env:
      FIREFLIES_API_KEY: ${{ secrets.FIREFLIES_API_KEY }}
    run: python scripts/weekly_meeting_report.py
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'fireflies-ai',
  'models',
  'Fireflies.ai AI モデル — AskFred AI アシスタント + 会議分析エンジン + 多言語対応',
  $$## Fireflies.ai AI 技術詳細

### コア AI 機能

| 機能 | 技術詳細 |
|------|---------|
| **文字起こし** | 独自 ASR + OpenAI Whisper ベース強化 / 話者分離 (diarization) |
| **AI 要約** | GPT-4 ベース要約エンジン / Smart Summary 5カテゴリ生成 |
| **Action Items 抽出** | Fine-tuned NLP モデル / 「〜してください」「〜を確認」等のパターン学習 |
| **センチメント分析** | 発言ごとのポジティブ/ネガティブ/ニュートラル分類 |
| **トーク比率分析** | 話者ごとの発言時間・割合・モノローグ時間を可視化 |
| **キーワードトラッカー** | 競合他社名・プロダクト名・価格等を事前登録して自動検出 |

### AskFred — 会議内 AI チャット
```
会議後に「AskFred に質問」する機能:
  「今日の会議でBudget に関して何が決まったか?」
  「田中さんが言ったリスクは何だったか?」
  「次回アクションアイテムを箇条書きにして」
→ GPT-4 が会議の文字起こし全体をコンテキストに回答
```

### Smart Summary の 5 カテゴリ
1. **Overview**: 会議全体の要約 (3-5文)
2. **Action Items**: タスク・担当者・期日
3. **Outline**: 時系列のアジェンダ再現
4. **Keywords**: 重要キーワードと登場回数
5. **Shorthand Bullets**: 箇条書き形式の決定事項

### 対応言語
100+ 言語 (日本語含む) — 日本語文字起こし精度: 良好 (ビジネス会話)

### セキュリティ / コンプライアンス
- SOC 2 Type II 認定
- GDPR 準拠
- HIPAA 対応 (Enterprise)
- エンドツーエンド暗号化
- データ保存場所選択: US / EU

### 自分株式会社での活用可能性
- **チームミーティング自動化**: 社内定例会議を Fireflies で自動録音・要約 → Slack 通知
- **営業通話分析**: セールスコールのトーク比率・競合言及を GHA 週次レポートで可視化
- **WBS 自動更新**: AskFred で「今日決まったタスク」を抽出 → tools-hub:wbs.add_task に自動連携
- **AI 大学コンテンツ生成元**: 専門家インタビュー音声 → Fireflies 文字起こし → AI 大学記事化
- **顧客 MTG 記録**: CS チェックメモ (docs/cs-notes/) に自動追記 (Fireflies Webhook + GHA)$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 216→217社化: Fireflies.ai 追加',
  'PS#3 S61。Fireflies.ai (AI会議アシスタント / Fred Bot自動参加 / AI要約+Action Items / CRM統合 / GraphQL API / AskFred AIチャット / セールス分析 / ~$19M / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
