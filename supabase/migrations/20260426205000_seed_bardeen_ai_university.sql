-- PS#3 S65: AI大学 224→225社化 — Bardeen 追加
-- Bardeen: AIブラウザ自動化 / ノーコード / Scraper / CRM統合 / プロンプト→自動化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bardeen',
  'overview',
  'Bardeen — AIブラウザ自動化 (ノーコード/プロンプト→Automation/Scraper/CRM統合)',
  $$## Bardeen — AIブラウザ自動化プラットフォーム

**カテゴリ**: Browser Automation / No-Code / AI Workflow / Web Scraping
**設立**: 2020年 / 本社: San Francisco, CA / 資金調達: ~$15M (Insight Partners / Sequoia Scout)
**特徴**: Chrome拡張機能 + AIで「Webブラウザの操作を自動化」するノーコードツール。プロンプト入力だけで自動化フローを生成
**ユーザー**: セールス担当 / リクルーター / マーケター / オペレーション / SaaS ユーザー
**評価**: 8/9

### 概要
Bardeen は **「ブラウザの繰り返し作業をAIが自動化」** するChrome拡張ツール。LinkedIn/Salesforce/Notion/Gmailなど普段使いのWebアプリをまたいだワークフローを、コードなしで構築できる。2024年に **AI Magic Action** を追加し、「LinkedIn の○○さんの情報を Salesforce に追加して」などの自然言語命令だけで自動化フローを即時生成する機能を実現。Zapier が「アプリ間API連携」なら、Bardeen は「実際のブラウザ画面を操作する自動化」という点で差別化される。

### 主な機能

**ノーコード自動化 (Playbooks)**
- Trigger (スケジュール / Webpageイベント / 手動) → Actions の連鎖を視覚的に構築
- 600+ 事前構築テンプレート (LinkedIn Lead Gen / Job Tracker / Content Repurpose等)
- 変数・条件分岐・ループ対応

**AI Magic Action (2024)**
- 自然言語でアクション生成: 「このページのデータをスプレッドシートにまとめて」
- Scraper AI: 任意のWebページ構造を自動解析してデータ抽出
- Summarizer: 長文ページを要約してSlackに送信
- Email Composer: コンテキストを読んでメール下書き自動生成

**統合アプリ (70+)**
| カテゴリ | 対応 |
|---------|------|
| CRM | Salesforce / HubSpot / Pipedrive / Airtable |
| コミュニケーション | Gmail / Slack / Notion / Linear |
| ソーシャル | LinkedIn / Twitter/X / GitHub |
| データ | Google Sheets / Snowflake / PostgreSQL |
| 採用 | Greenhouse / Lever / Workable |

**Scraper (Webスクレイピング)**
- ページ構造を自動認識してデータを構造化抽出
- ページネーション対応 (複数ページを自動巡回)
- 抽出データをGoogle Sheets / Airtable / Notion に直接書き込み
- JavaScriptレンダリングされた動的ページも対応 (Chromiumベース)

### ユースケース

**Sales Automation (最多利用)**
```
LinkedIn Sales Navigator で検索
→ Bardeen が候補者リストをスクレイプ
→ 各候補者の会社・役職・メール推定を自動取得
→ HubSpot/Salesforce に自動追加
→ Gmail でパーソナライズされたコールドメール送信
```

**Recruiting Automation**
```
LinkedIn で候補者検索
→ Bardeen が候補者情報をスクレイプ
→ ATS (Greenhouse/Lever) に自動追加
→ プロフィールをNotionのカンバンに整理
→ 候補者にパーソナライズした招待メール送信
```

### 競合との差別化
| 項目 | Bardeen | Zapier | Make | n8n |
|------|---------|--------|------|-----|
| ブラウザ操作 | ✅ 実際の画面 | ❌ (APIのみ) | ❌ | ❌ |
| AI自動生成 | ✅ Magic Action | △ | △ | △ |
| Webスクレイピング | ✅ 組込 | ❌ | ❌ | ❌ |
| 設定難易度 | 極低 | 低 | 中 | 高 |
| 対応アプリ数 | 70+ | 6000+ | 1200+ | 400+ |
| 価格 | 安 | 高 | 中 | 安 |

### 導入コスト
- **Free**: 月250クレジット / 基本自動化 / Scraper
- **Professional**: 月$10 / 無制限 / AI Magic Action / 優先サポート
- **Business**: 月$20/ユーザー / チーム共有 / 高度な統合
- **Enterprise**: カスタム / SSO / 専任サポート / オンプレ$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bardeen',
  'api',
  'Bardeen API — Playbook実行・Scraper・Chrome拡張連携 (Python/JavaScript)',
  $$## Bardeen API

### 概要
Bardeen は REST API を提供。外部からPlaybookをトリガー、Scraperジョブを制御できる。

### セットアップ
```bash
# Bardeen → Settings → API Keys でキー取得
export BARDEEN_API_KEY="your_api_key_here"
export BARDEEN_BASE="https://api.bardeen.ai/api/v1"
```

### Playbook 一覧取得・実行
```python
import requests
import os

BARDEEN_API_KEY = os.environ["BARDEEN_API_KEY"]
BARDEEN_BASE = os.environ["BARDEEN_BASE"]

HEADERS = {
    "Authorization": f"Bearer {BARDEEN_API_KEY}",
    "Content-Type": "application/json",
}

def list_playbooks() -> list:
    """保存済みPlaybook一覧を取得"""
    resp = requests.get(f"{BARDEEN_BASE}/playbooks", headers=HEADERS)
    resp.raise_for_status()
    return resp.json().get("playbooks", [])

def run_playbook(playbook_id: str, inputs: dict = None) -> dict:
    """Playbookをトリガー実行"""
    resp = requests.post(
        f"{BARDEEN_BASE}/playbooks/{playbook_id}/run",
        json={"inputs": inputs or {}},
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# Playbook一覧
playbooks = list_playbooks()
for pb in playbooks:
    print(f"{pb['name']} (ID: {pb['id']})")

# LinkedIn→HubSpot Playbook を実行
result = run_playbook(
    playbook_id="pb_linkedin_to_hubspot",
    inputs={"linkedin_url": "https://linkedin.com/in/example-person"},
)
print(f"実行ID: {result['runId']} / ステータス: {result['status']}")
```

### Scraper API (Webデータ抽出)
```python
def scrape_page(url: str, schema: dict) -> list:
    """指定URLからschemaに従ってデータを抽出"""
    payload = {
        "url": url,
        "schema": schema,  # 抽出したいフィールド定義
        "pagination": {
            "type": "next_button",
            "max_pages": 5,
        },
    }
    resp = requests.post(
        f"{BARDEEN_BASE}/scraper",
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json().get("data", [])

# AI系スタートアップのProduct Huntページをスクレイプ
ph_data = scrape_page(
    url="https://www.producthunt.com/topics/artificial-intelligence",
    schema={
        "product_name": "製品名",
        "tagline": "キャッチコピー",
        "upvotes": "アップ票数",
        "comments": "コメント数",
        "launch_date": "ローンチ日",
    },
)
for item in ph_data[:5]:
    print(f"{item['product_name']}: {item['upvotes']} votes")
```

### GHA × Bardeen 競合モニタリング自動化
```yaml
# .github/workflows/competitor-scraping.yml
# 週次でBardeen API → 競合LP変更をスクレイプ → Supabaseに保存
steps:
  - name: Scrape competitor landing pages
    env:
      BARDEEN_API_KEY: ${{ secrets.BARDEEN_API_KEY }}
      SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
    run: |
      python scripts/competitor_scraping.py \
        --competitors notion,evernote,moneyforward \
        --fields "pricing,features,cta_text"
```

### Chrome拡張連携 (JavaScript)
```javascript
// Bardeen Chrome拡張のContentScriptとの通信
// (Chrome拡張がインストールされている場合のみ動作)

// Bardeenに自動化命令を送信
window.postMessage({
  type: "BARDEEN_RUN_COMMAND",
  command: "scrape_current_page",
  config: {
    schema: {
      title: "ページタイトル",
      price: "料金プラン",
    },
    output: "google_sheets",
  },
}, "*");

// 結果を受信
window.addEventListener("message", (event) => {
  if (event.data.type === "BARDEEN_RESULT") {
    console.log("スクレイプ結果:", event.data.result);
  }
});
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'bardeen',
  'models',
  'Bardeen AI技術詳細 — Magic Action LLM + Scraper AI + RPA×AIの融合アーキテクチャ',
  $$## Bardeen AI 技術詳細

### AI Magic Action のアーキテクチャ
```
ユーザー入力 (自然言語):
  「LinkedIn でデータサイエンティストを検索して HubSpot に追加して」
       ↓
Intent Parser (GPT-4):
  - タスクを分解: [検索] [スクレイプ] [CRM追加] の3ステップ
  - 必要なアプリを特定: LinkedIn, HubSpot
  - 入力変数を識別: job_title="データサイエンティスト", location=未指定
       ↓
Playbook Generator:
  - 既存テンプレートライブラリから近似テンプレートを検索
  - テンプレートを入力変数でカスタマイズ
  - 実行可能なPlaybook JSONを生成
       ↓
Execution Engine (Chromiumベース):
  - 生成されたPlaybookをChrome拡張で実行
  - 実際のブラウザセッションを使ってWebアプリを操作
  - DOM操作 + JavaScript実行 で動的ページにも対応
       ↓
出力: HubSpot にコンタクト自動追加 + 実行レポート
```

### Scraper AI の仕組み
```
DOM解析フェーズ:
  1. URLにアクセス → ページHTML/DOMを取得
  2. LLMがページ構造を解析:
     - 繰り返しパターン (リスト/グリッド) を検出
     - 各アイテムのフィールドを推定 (名前/価格/日付等)
  3. CSSセレクタを自動生成 (jQuery/XPath)

抽出フェーズ:
  4. セレクタでデータを抽出
  5. データクリーニング (テキスト正規化/日付変換)
  6. ページネーション: "次のページ"ボタンを自動検出して繰り返し

品質チェック:
  7. 抽出データの一貫性検証 (型チェック/必須フィールド確認)
  8. エラーレート閾値超過 → 自動リトライ or ユーザーに修正依頼
```

### RPA (Robotic Process Automation) × AI の融合
```
従来のRPA (UiPath/Automation Anywhere):
  - ルールベース: 「A座標をクリック → Bフィールドに入力」
  - UI変更に脆く壊れやすい / エンジニア必須

Bardeen の AI-RPA:
  - 目的ベース: 「○○という情報を取得する」をAIが解釈して実行
  - DOM構造の変化を LLM が吸収 (セレクタ自動修正)
  - プロンプト1行でフローを生成/修正できる
  - ノーコードだが API/GHAからもトリガー可能

→ 「人間がブラウザでやることを全部自動化」というコンセプト
```

### Zapier vs Bardeen 使い分け指針 (2026年)
```
Bardeen が優位なケース:
  ✅ Webページを直接スクレイプしたい
  ✅ LinkedIn / Twitter などブラウザ操作が必要
  ✅ APIなしのWebアプリを自動化したい
  ✅ プロンプト1行でフロー生成したい (AI Magic Action)

Zapier が優位なケース:
  ✅ REST APIを持つサービス間連携
  ✅ 6,000+ アプリとの統合
  ✅ エンタープライズ / 高可用性が必要
  ✅ Webhook / cron トリガーが主体
```

### 自分株式会社での活用可能性
- **AI大学 RSS収集**: Bardeen Scraper → 各AIプロバイダーの公式ブログを定期スクレイプ → ai_university_content 自動更新
- **競合LP監視**: competitors テーブルの190社のLP変化を週次 Bardeen スクレイプで検出 → Supabase に差分記録
- **LinkedIn採用**: Bardeen Magic Action → 採用候補者をLinkedIn検索 → Notionカンバンに自動整理
- **Product Hunt 監視**: AI カテゴリの新着製品を Bardeen でスクレイプ → Slack #ai-news に自動投稿
- **競合価格監視**: 定期的に競合21社の料金ページをスクレイプ → 価格変更を即検知してアラート$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 224→225社化: Bardeen 追加',
  'PS#3 S65。Bardeen (AIブラウザ自動化/Chrome拡張/Magic Action自然言語→Playbook生成/Scraper AI構造化抽出/LinkedIn×CRM統合/70+アプリ/Insight Partners/~$15M/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
