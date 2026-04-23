-- Session PS#3-S28: AI大学 150社化 — Glean 追加
-- Arvind Jain (元 Google 検索・インフラ VP) が 2019 年に創業した企業向け AI 検索 + Work AI。
-- 2025-09 Series E $260M @ $4.6B → 2025-06 Series F $150M @ $7.2B valuation。
-- $100M+ ARR 達成 / Fortune 500 含む 1,000+ 企業が導入 / 年間 1 億件以上の agent action。
-- Slack / Google Drive / Jira / Salesforce など 100+ データソースを横断検索する「Work Knowledge Graph」。
-- Agents API + Hosted MCP Server で外部 AI エコシステムと open interoperability 対応。
-- 既存 149 社に空白だった「エンタープライズ Work AI / 企業知識グラフ検索」軸を埋める。
-- Step 0: 7.5/9 (エンタープライズ特化 / 個人ユーザー直接利用は限定的)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'glean',
  'overview',
  'Glean — Fortune 500 御用達の企業 AI 検索 + Work AI エージェントプラットフォーム',
  $md$
# Glean — Enterprise Work AI

2019 年 Palo Alto 創業。CEO **Arvind Jain** (元 Google 検索・分散インフラ VP) ら Google
出身チームが「企業の中に散在するあらゆる知識を一発で検索できる AI」を目指して設立。

Slack、Google Drive、Jira、Salesforce、Confluence、GitHub など **100 以上のデータソース**
を横断する **Work Knowledge Graph** を構築し、LLM ベースの検索・会話・エージェントを提供。

## 主要プロダクト
- **Glean Assistant** — 社内データを参照して質問に答える AI アシスタント
- **Glean Search** — 意味的コンテキスト理解による全社横断検索
- **Glean Agents** — 社内データを使って自律実行できる AI エージェント群
  - Hosted MCP Server + Agents API で外部 AI システムと接続可能
  - 100M+ agent actions / 年 (2026-01 時点)
- **Glean Apps** — ノーコードで部門専用 AI アシスタントを構築

## 強み
| 強み | 内容 |
|------|------|
| 企業データ横断検索 | 100+ コネクタ / 許可ベースのデータアクセス (RLS 相当) |
| Work Knowledge Graph | 社員・プロジェクト・ドキュメントの関係性を Graph DB で管理 |
| エンタープライズセキュリティ | SOC 2 Type II / HIPAA / GDPR / 各国データ主権対応 |
| MCP 対応 | Hosted MCP Server 公開 → Claude / Cursor など外部 AI から利用可 |
| パーソナライゼーション | ユーザーごとの職種・プロジェクト・言語を学習して回答精度向上 |

## 資金調達・バリュエーション
| ラウンド | 時期 | 金額 | バリュエーション |
|----------|------|------|------------------|
| Series A | 2020 | $40M  | —               |
| Series B | 2021 | $55M  | —               |
| Series C | 2022 | $200M | $1B (unicorn)   |
| Series D | 2023 | $200M | $2.2B           |
| Series E | 2024-09 | $260M | $4.6B        |
| Series F | 2025-06 | $150M | **$7.2B**    |
| 累計     | 2025 | $905M+ | $7.2B         |

リード投資家: Kleiner Perkins / Sequoia / Lightspeed / Wellington Management など

## 成長指標
- **ARR $100M+** 達成 (2025-06 時点)
- **1,000+ 企業** 導入 (Duolingo / Databricks / Coatue など Fortune 500 含む)
- **100M+ agent actions/年** (Glean Agents)
- **従業員規模**: 1,000 人以上 (2026 年時点)

## 自分株式会社での活用
- **AI大学 企業 AI 軸**: 個人 AI (Claude/Gemini) vs 企業 AI (Glean) の対比コンテンツ
- **社内知識管理**: 競合監視レポート / 技術ドキュメントへの横断検索 → 将来 integration 候補
- **MCP 連携**: Glean MCP Server → Claude Code から社内ドキュメント参照 (エンタープライズ段階)
$md$,
  'https://www.glean.com/',
  '2026-04-24',
  1
),

(
  'glean',
  'models',
  'Glean プロダクト一覧 (2026) — Search / Assistant / Agents / Apps',
  $md$
# Glean プロダクト・機能一覧 (2026年4月時点)

## コア機能

| 機能 | 説明 | 技術的特徴 |
|------|------|-----------|
| **Glean Search** | 全社横断の意味検索 | Work Knowledge Graph + dense retrieval |
| **Glean Assistant** | RAG ベース Q&A + 要約 | 社内データ参照 + 外部 LLM 組み合わせ |
| **Glean Agents** | 自律実行 AI エージェント | MCP / Agents API 対応 |
| **Glean Apps** | 部門別 AI アシスタント作成 | ノーコード / カスタム system prompt |
| **Glean Translate** | 多言語ドキュメント翻訳 | 100+ 言語対応 |

## データコネクタ (100+ 種類)

| カテゴリ | 代表的なコネクタ |
|---------|---------------|
| コミュニケーション | Slack / Teams / Gmail / Zoom |
| ドキュメント | Google Drive / SharePoint / Confluence / Notion |
| タスク管理 | Jira / Asana / Linear / GitHub Issues |
| CRM / 営業 | Salesforce / HubSpot / Zendesk |
| コード | GitHub / GitLab / Bitbucket |
| データ | Snowflake / BigQuery / Looker |

## Glean Agents プラットフォーム (2026 強化)

```text
[外部 AI (Claude / Cursor / etc.)]
         │ MCP Protocol
         ▼
[Glean Hosted MCP Server]
         │
         ▼
[Work Knowledge Graph]  ←─  社内 100+ データソース
         │
         ▼
[Agents API]  ─→  自律 agent 実行 (承認ワークフロー含む)
```

- **MCP Server (Hosted)**: 外部 AI から Glean の社内データを参照可能
- **Agents API**: カスタムエージェントを Glean 上で実行
- **100M+ agent actions/年** の実績 (2026-01)

## LLM バックエンド
Glean は特定の LLM に依存せず、**マルチ LLM アーキテクチャ**を採用:
- Claude (Anthropic) / GPT-4o (OpenAI) / Gemini (Google) を用途に応じて切替可
- 企業は自社 LLM キーを BYO (Bring Your Own) で設定可能

## セキュリティ・コンプライアンス
- SOC 2 Type II / ISO 27001 / GDPR / HIPAA 対応
- 社員のアクセス権限を元データから継承 (Jira の閲覧権限 = Glean の検索権限)
- データは Glean クラウド内で暗号化 + ゼロ知識インデックス オプション

## 料金
- **エンタープライズ向け契約のみ** (公開価格なし)
- 参考: 中堅企業 1,000 名規模で年間数百万円〜数千万円の範囲 (業界慣行)
- 無料トライアル / デモリクエスト: https://www.glean.com/demo
$md$,
  'https://www.glean.com/blog/glean-series-f-announcement',
  '2026-04-24',
  2
),

(
  'glean',
  'api',
  'Glean API 入門 — Agents API・MCP Server・Indexing API',
  $md$
# Glean API の始め方

Glean は主に **エンタープライズ SaaS** として提供されるが、以下の開発者向け API も提供。

## 主要 API 一覧

| API | 用途 | 認証 |
|-----|------|------|
| **Agents API** | カスタムエージェントの実行・管理 | OAuth 2.0 / API Token |
| **Indexing API** | カスタムデータソースのインデックス追加 | Service Token |
| **Search API** | プログラムから検索実行 | User Token |
| **MCP Server** | 外部 AI からの社内データ参照 | MCP 標準認証 |

## Indexing API — カスタムデータを Glean に追加

```python
import requests

# カスタムドキュメントを Glean にインデックス
response = requests.post(
    "https://YOUR_DOMAIN.glean.com/rest/api/v1/indexdocument",
    headers={
        "Authorization": "Bearer YOUR_INDEXING_TOKEN",
        "Content-Type": "application/json",
    },
    json={
        "document": {
            "id": "custom-doc-001",
            "datasource": "custom_datasource",
            "title": "自社ナレッジベース記事 001",
            "body": {"mimeType": "text/plain", "textContent": "記事本文..."},
            "viewURL": "https://your-company.com/kb/001",
            "permissions": {
                "allowedUsers": [{"email": "user@company.com"}],
            },
        }
    },
)
print(response.status_code)
```

## MCP Server 接続 (Claude Code からの利用)

```json
// claude_desktop_config.json
{
  "mcpServers": {
    "glean": {
      "command": "npx",
      "args": ["@glean/mcp-server"],
      "env": {
        "GLEAN_API_TOKEN": "YOUR_GLEAN_API_TOKEN",
        "GLEAN_INSTANCE": "your-company.glean.com"
      }
    }
  }
}
```

## Search API — プログラムからの検索

```python
import requests

response = requests.post(
    "https://YOUR_DOMAIN.glean.com/rest/api/v1/search",
    headers={"Authorization": "Bearer YOUR_USER_TOKEN"},
    json={
        "query": "Q4 売上レポート",
        "pageSize": 10,
        "requestOptions": {"facetFilters": [{"fieldName": "datasource", "values": ["gdrive"]}]},
    },
)
results = response.json().get("results", [])
for r in results:
    print(r["title"], r["url"])
```

## アクセス方法
- エンタープライズ契約後、管理者から API Token を発行
- 無料デモ: https://www.glean.com/demo
- 開発者ドキュメント: https://developers.glean.com/
- MCP Server: https://github.com/gleanwork/mcp-server

## 料金 (2026年4月時点)
- **企業契約のみ** (個人開発者向け無料プランなし)
- 開発・評価: デモアカウントまたはパートナープログラムを通じて相談
$md$,
  'https://developers.glean.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
