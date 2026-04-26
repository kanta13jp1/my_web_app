-- PS#3 S62: AI大学 219→220社化 — Zapier AI 追加
-- Zapier AI: ワークフロー自動化の王者 / AI機能大幅強化 / 6000+アプリ連携 / Zapier Central

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'zapier-ai',
  'overview',
  'Zapier AI — ワークフロー自動化 × AI統合 (6000+アプリ連携 / Zapier Central / AI Actions)',
  $$## Zapier AI — ワークフロー自動化 × AI プラットフォーム

**カテゴリ**: Workflow Automation / AI Integration Platform / No-Code
**設立**: 2011年 / 本社: San Francisco, CA (リモートファースト) / 評価額: **$5B (2021年)**
**特徴**: 6,000+ アプリを繋ぐノーコード自動化ツールが AI 機能を全面統合
**ユーザー**: スタートアップ / マーケター / SMB / RevOps / ノーコード開発者
**評価**: 9/9

### 概要
Zapier は「Zap」と呼ばれる自動化ワークフローで 6,000+ のアプリを繋ぐノーコード自動化プラットフォーム。2023〜2024年に AI 機能を大幅強化し、単なる「if-then 自動化」から **AI エージェントによる自律的なワークフロー実行**へと進化した。競合の Make (旧 Integromat) / n8n より設定の簡単さと対応アプリ数で優位。

### 主な機能

**ノーコード自動化 (Zaps)**
- Trigger → Action の単純なワークフロー
- 例: 「Gmail に新メールが届いたら → Slack に通知して → スプレッドシートに記録」
- マルチステップ Zap (複数アクションの連鎖) / フィルター / パス / ループ

**AI 統合機能 (2023〜2024 大幅強化)**
| 機能 | 説明 |
|------|------|
| **AI by Zapier** | Zap 内で ChatGPT / Claude / Gemini を直接呼び出してデータ変換・要約・分類 |
| **Zapier Central** | AI エージェントが自律的にタスクを実行 (人間の承認なしに複数ステップを判断) |
| **AI Actions** | LLM から Zapier の 6,000 アプリに直接アクションを実行 (ChatGPT Plugins 互換) |
| **Natural Language Zaps** | 「毎朝 9 時に昨日の売上をスプレッドシートにまとめて Slack に送る」を自然言語で Zap 化 |
| **Formatter AI** | テキストの整形・抽出・変換を AI で自動実行 |
| **Chatbots** | ノーコードで AI チャットボットを構築 (Zendesk / HubSpot / Slack に埋め込み) |

### Zapier Central (AI エージェント) — 2024
```
従来の Zap: Trigger → (事前定義ステップ) → Action  [決定論的]

Zapier Central: Task → AI Agent が状況を判断 → 動的に複数アプリを操作  [自律的]

例: 「競合の価格変動を検出したら、プライシングチームに Slack で報告し、
       社内 CRM の見込み客フォローアップメールの件名を自動更新して、
       次の週次ミーティングのアジェンダに追加」
→ AI が状況を読んで最適なアクションを自律判断・実行
```

### 対応アプリ (主要)
Google (Sheets/Docs/Gmail/Calendar/Drive) / Slack / HubSpot / Salesforce /
Notion / Airtable / Jira / Trello / GitHub / Stripe / Shopify /
ChatGPT / Claude (Anthropic) / OpenAI / Gemini / Typeform / Mailchimp /
Supabase / Firebase / Twilio / SendGrid / LinkedIn / Twitter/X / ...6,000+

### 導入コスト
- **Free**: 月 100 タスク / 5 Zap / 基本アプリのみ
- **Starter**: 月 $19.99 / 750 タスク / マルチステップ Zap
- **Professional**: 月 $49 / 2,000 タスク / フィルター / パス / Formatter
- **Team**: 月 $69 / 2,000 タスク / 共同編集 / 共有フォルダ
- **Company**: カスタム / SAML SSO / 高度な権限 / 専任CSM
- **Zapier Central**: 月 $20+ (プレビュー / エージェント機能)$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'zapier-ai',
  'api',
  'Zapier API / AI Actions — LLMからZapierアプリを操作 + Webhook Trigger (Python)',
  $$## Zapier API / AI Actions

### 2種類のアクセス方法

**1. Zapier REST API (管理操作)**
```bash
# https://zapier.com/app/settings/api でAPIキー取得
export ZAPIER_API_KEY="your_api_key_here"
```

```python
import requests
import os

ZAPIER_API_KEY = os.environ["ZAPIER_API_KEY"]
ZAPIER_BASE = "https://api.zapier.com/v1"

def list_zaps() -> list:
    resp = requests.get(
        f"{ZAPIER_BASE}/zaps",
        headers={"X-API-Key": ZAPIER_API_KEY},
    )
    resp.raise_for_status()
    return resp.json().get("objects", [])

zaps = list_zaps()
for z in zaps:
    print(f"{z['title']} — {z['status']}")
```

**2. Webhook Trigger Zap (Zapier にデータを送信)**
```python
def trigger_zap_webhook(webhook_url: str, payload: dict) -> dict:
    """Webhook URL に POST して Zap をトリガー"""
    resp = requests.post(webhook_url, json=payload)
    resp.raise_for_status()
    return resp.json()

# Zap の Trigger = "Webhooks by Zapier → Catch Hook"
# webhook_url は Zapier の Trigger 設定画面に表示される
WEBHOOK_URL = os.environ["ZAPIER_WEBHOOK_URL"]

# 例: 新規ユーザー登録時にマーケティング自動化をトリガー
trigger_zap_webhook(WEBHOOK_URL, {
    "event": "new_user_signup",
    "user_email": "user@example.com",
    "user_name": "田中 太郎",
    "plan": "pro",
    "signup_date": "2026-04-26",
})
```

### AI Actions — LLM から Zapier を操作
```python
# AI Actions により、Claude/ChatGPT から直接 Zapier 操作が可能
# Zapier → AI Actions → Action を作成してエンドポイントを取得

import anthropic

client = anthropic.Anthropic()

# Claude に Zapier AI Actions ツールを渡す
tools = [
    {
        "name": "create_slack_message",
        "description": "Zapier 経由で Slack チャンネルにメッセージを送信",
        "input_schema": {
            "type": "object",
            "properties": {
                "channel": {"type": "string", "description": "Slack チャンネル名"},
                "message": {"type": "string", "description": "送信するメッセージ"},
            },
            "required": ["channel", "message"],
        },
    },
    {
        "name": "add_hubspot_contact",
        "description": "Zapier 経由で HubSpot に新しいコンタクトを追加",
        "input_schema": {
            "type": "object",
            "properties": {
                "email": {"type": "string"},
                "first_name": {"type": "string"},
                "company": {"type": "string"},
            },
            "required": ["email"],
        },
    },
]

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=tools,
    messages=[{
        "role": "user",
        "content": "田中太郎 (tanaka@example.com, ABC株式会社) が問い合わせフォームを送信。"
                   "HubSpot に追加して、#sales-team チャンネルに通知して。",
    }],
)

# tool_use ブロックを処理して Zapier AI Actions エンドポイントに POST
for block in response.content:
    if block.type == "tool_use":
        zapier_action_url = f"https://actions.zapier.com/api/v1/exposed/{block.name}/execute/"
        requests.post(
            zapier_action_url,
            json={"instructions": str(block.input)},
            headers={"X-API-Key": ZAPIER_API_KEY},
        )
```

### GHA × Zapier 連携 (deploy 通知自動化)
```yaml
# deploy-prod.yml の最後に追加
- name: Notify via Zapier on deploy success
  if: success()
  run: |
    curl -X POST "${{ secrets.ZAPIER_DEPLOY_WEBHOOK }}" \
      -H "Content-Type: application/json" \
      -d '{"event":"deploy_success","commit":"${{ github.sha }}","branch":"${{ github.ref_name }}"}'
# → Zapier が Slack 通知 + Supabase ログ記録 + 任意の自動化を実行
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'zapier-ai',
  'models',
  'Zapier AI 技術詳細 — Zapier Central エージェント + AI by Zapier + Make/n8n との比較',
  $$## Zapier AI 技術詳細

### Zapier Central のアーキテクチャ
```
User Input (自然言語タスク)
       ↓
Zapier AI Orchestrator (LLM: GPT-4 Turbo)
       ↓
┌──────────────────────────────────────────┐
│  Tool Selection (6,000+ アプリから選択)   │
│  - Gmail: メール読み書き                   │
│  - Salesforce: CRM 操作                  │
│  - Slack: メッセージ送受信               │
│  - Google Sheets: データ読み書き          │
└──────────────────────────────────────────┘
       ↓
Multi-Step Execution (順次・並行)
       ↓
Result Synthesis → ユーザーに報告
```

### AI by Zapier — Zap 内 AI ステップ
```
Zap の Action ステップとして "AI by Zapier" を追加:

対応 AI モデル:
- ChatGPT (GPT-4o / GPT-4 Turbo)
- Claude (claude-sonnet-4-6 / claude-haiku-4-5)
- Gemini Pro
- Cohere Command
- 独自モデル (Claude API キーを直接入力も可)

主なユースケース:
- テキスト要約: メールを 3 行に要約して Slack に送る
- データ分類: フォーム回答を 5 カテゴリに自動分類
- 翻訳: 英語の問い合わせを日本語に翻訳してチームに配信
- 感情分析: カスタマーレビューのセンチメントを判定
- 構造化: 自由記述のデータを JSON に変換して DB に保存
```

### Zapier vs Make (Integromat) vs n8n
| 項目 | Zapier | Make | n8n |
|------|--------|------|-----|
| 対応アプリ | **6,000+** | 1,200+ | 400+ |
| 操作性 | ★★★★★ (最も簡単) | ★★★★ | ★★★ |
| 価格 | 高め | 中 | 安 (OSS) |
| AI 機能 | ★★★★★ (Central) | ★★★ | ★★★ (AI Agent) |
| カスタマイズ | 低 | 高 | **最高** (OSS) |
| Enterprise | ✅ | ✅ | ✅ Self-host |
| 日本語サポート | △ (英語中心) | △ | △ |

### 自分株式会社での活用可能性
- **Supabase → Slack 通知**: 新規ユーザー登録 → Zapier → #new-users チャンネル通知
- **GitHub Issue → WBS 同期**: Zapier で issue-to-wbs.yml の補助トリガー
- **フォーム → CRM**: 問い合わせフォーム回答を Zapier AI で分類 → HubSpot 自動追加
- **deploy 通知**: GHA deploy 完了 → Zapier → Slack + メール + カレンダー記録
- **AI 大学 RSS**: 各 AI プロバイダーの RSS → Zapier → Supabase ai_university_content 自動追加
- **Zapier Central 活用**: 「昨日の AI ニュースをまとめて X に投稿して」を自律実行

### Zapier の競争優位性 (2025〜2026)
1. **6,000 アプリのモート**: 新規参入者が追いつくのに最低 5 年以上
2. **AI Actions の標準化**: OpenAI / Anthropic の公式 Tool 実装として採用
3. **Zapier Central の差別化**: 単純 Zap から AI エージェントへの進化
4. **企業浸透率**: Fortune 500 の 87% が Zapier を利用$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 219→220社化: Zapier AI 追加',
  'PS#3 S62。Zapier AI (ワークフロー自動化×AI/6000+アプリ/Zapier Central エージェント/AI Actions/Natural Language Zaps/$5B評価/Fortune500 87%利用/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
