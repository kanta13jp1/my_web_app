-- Session PS#3-S48: AI大学 193→194社化 — n8n 追加
-- オープンソースのワークフロー自動化プラットフォーム。400+ の統合と AI Agent ノードを搭載し、
-- LLM と外部サービスを組み合わせた自動化パイプラインをビジュアルに構築できる。
-- GitHub 40k+ Stars / Apache 2.0 + Commons Clause / セルフホスト可。
-- Step 0: 8/9 (Make/Zapier OSS代替 / AI Agentノード / 40k+Stars / セルフホスト / 400+統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'n8n',
  'overview',
  'n8n — AI Agent ノード内蔵のオープンソースワークフロー自動化プラットフォーム',
  $md$
# n8n — Open Source Workflow Automation with AI

**Make (旧Integromat) や Zapier のオープンソース代替**として人気の
ワークフロー自動化プラットフォーム。

**400+ のサービス統合**と**AI Agent ノード**を搭載し、
LLM を組み込んだインテリジェントな自動化パイプラインを
ビジュアルエディタで構築できる。セルフホスト可能。

GitHub **40,000+ Stars** / Apache 2.0 + Commons Clause ライセンス。

## Make / Zapier との比較

| 機能 | n8n | Make (Integromat) | Zapier |
| :--- | :--- | :--- | :--- |
| **価格** | セルフホスト無料 | $9/月〜 | $19.99/月〜 |
| **オープンソース** | ✅ | — | — |
| **AI Agent ノード** | ✅ | 限定的 | 限定的 |
| **コード実行** | ✅ (JS/Python) | 限定 | — |
| **カスタム統合** | ✅ 完全自由 | 限定 | 限定 |
| **データ変換** | ✅ 高度 | 標準 | 標準 |
| **セルフホスト** | ✅ | — | — |

## 主要機能

### AI Agent ノード
- **AI Agent**: LLM + ツール + メモリを組み合わせた自律エージェント
- **OpenAI / Anthropic / Google AI**: 主要 LLM プロバイダーに直接接続
- **Vector Store ノード**: Pinecone/Supabase pg_vector との連携
- **Summarize**: テキスト要約の自動化

### ビジュアルワークフロービルダー
- ドラッグ&ドロップでノードを接続
- 条件分岐・ループ・並列処理に対応
- リアルタイムデバッグ (各ノードの入出力を確認)

### 400+ 統合

| カテゴリ | サービス |
| :--- | :--- |
| コミュニケーション | Slack, Discord, Gmail, Outlook, Teams |
| 開発ツール | GitHub, GitLab, Linear, Jira |
| データベース | PostgreSQL, MySQL, MongoDB, Supabase |
| AI/ML | OpenAI, Anthropic, Google AI, Hugging Face |
| 生産性 | Google Sheets, Notion, Airtable, Trello |

## ユースケース

1. **AI カスタマーサポート**: メール受信 → LLM で分類 → 回答生成 → 送信
2. **CI/CD 通知**: GitHub Actions 失敗 → Slack 通知 → Issue 自動作成
3. **データパイプライン**: Supabase → 加工 → BigQuery → ダッシュボード更新
4. **コンテンツ生成**: RSS フィード → LLM で要約 → SNS 自動投稿
5. **RAG 更新**: ドキュメント変更検知 → Embedding → Vector Store 更新
$md$,
  'https://n8n.io/',
  '2026-04-25',
  1
),

(
  'n8n',
  'api',
  'n8n 入門 — セットアップ・AI Agent ワークフロー・Supabase 統合',
  $md$
## インストール (セルフホスト)

```bash
# Docker で起動 (推奨)
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  docker.n8n.io/n8nio/n8n

# または npm
npm install n8n -g
n8n start

# ブラウザで開く
open http://localhost:5678
```

---

## 基本ワークフロー: GitHub → Slack 通知

```
[GitHub Trigger]
  ↓ (new issue が作成された)
[IF: label = "bug"]
  ↓ YES
[Slack: #bugs チャンネルに通知]
  ↓
[GitHub: "bug-triaged" ラベルを追加]
```

設定:
1. **GitHub Trigger** ノード → Events: `Issues` → Action: `opened`
2. **IF** ノード → Condition: `label.name` equals `bug`
3. **Slack** ノード → Channel: `#bugs` → Message: `新しいバグ: {{$node.GitHub.json.title}}`

---

## AI Agent ワークフロー

```
[Manual Trigger / Webhook]
  ↓
[AI Agent]
  ├── LLM: Claude (Anthropic)
  ├── Memory: Window Buffer (会話履歴)
  └── Tools:
       ├── GitHub Tool (Issues 検索・作成)
       ├── Slack Tool (メッセージ送信)
       └── Code Tool (JavaScript 実行)
  ↓
[Respond to Webhook]
```

AI Agent ノード設定:
```json
{
  "agent": "conversationalAgent",
  "model": {
    "provider": "anthropicChat",
    "model": "claude-sonnet-4-6",
    "temperature": 0.7
  },
  "systemMessage": "あなたは自分株式会社のAI開発アシスタントです。GitHub Issues を調べ、Slack に報告する役割を持ちます。",
  "tools": ["githubTool", "slackTool"]
}
```

---

## Supabase との統合

```
[Cron: 毎日 9:00]
  ↓
[Supabase: ai_university_content を取得]
  ↓
[Code: データを加工]
  ↓
[HTTP Request: RSS フィードを取得]
  ↓
[AI Agent: コンテンツを要約]
  ↓
[Supabase: 要約を更新]
```

Supabase ノード設定:
```json
{
  "operation": "select",
  "table": "ai_university_content",
  "filterType": "equal",
  "filterField": "category",
  "filterValue": "overview",
  "limit": 10
}
```

---

## Webhook で外部トリガー

```bash
# n8n の Webhook URL を取得 (ノード設定画面から)
WEBHOOK_URL="https://your-n8n.com/webhook/abc123"

# curl で呼び出す
curl -X POST $WEBHOOK_URL \
  -H "Content-Type: application/json" \
  -d '{"message": "新しいプロバイダーを追加してください: OpenRouter"}'

# n8n がリクエストを受け取り → AI Agent が処理 → 結果を返す
```

---

## Code ノード (JavaScript)

```javascript
// n8n の Code ノードでカスタムロジックを実装
// 入力データを変換して出力

const items = $input.all();

return items.map(item => {
  const provider = item.json;

  return {
    json: {
      id: provider.id,
      displayName: provider.display_name,
      score: calculateScore(provider),
      recommendedFor: getRecommendations(provider.category),
    }
  };
});

function calculateScore(provider) {
  // stars, funding, relevance から総合スコアを計算
  const starScore = Math.min(provider.stars / 10000, 5);
  const fundingScore = provider.funding_usd > 100000000 ? 3 : 1;
  return (starScore + fundingScore).toFixed(1);
}
```

---

## n8n Cloud (ホスト型)

セルフホストが難しい場合は n8n Cloud を使用:
```
- starter プラン: $24/月 (5,000 実行/月)
- pro プラン: $60/月 (10,000 実行/月)
- エンタープライズ: カスタム
```
$md$,
  'https://docs.n8n.io/',
  '2026-04-25',
  2
),

(
  'n8n',
  'models',
  'n8n 本番運用 — AI パイプライン設計・エラー処理・このプロジェクト向け活用例',
  $md$
## AI パイプライン設計パターン

### パターン 1: RAG 更新パイプライン

```
[Cron: 毎時]
  ↓
[GitHub: 最新 commit を確認]
  ↓
[IF: ドキュメント変更あり]
  ↓ YES
[HTTP Request: 変更ファイルを取得]
  ↓
[Text Splitter: チャンク分割]
  ↓
[Embeddings: OpenAI text-embedding-3-small]
  ↓
[Supabase Vector Store: upsert]
  ↓
[Slack: "RAG 更新完了" 通知]
```

### パターン 2: AI カスタマーサポート

```
[Email Trigger: 新着メール]
  ↓
[AI Agent: 問い合わせ分類]
  ├── 技術的問題 → [GitHub Issue 作成] → [自動返信メール]
  ├── 課金問題   → [Slack #billing 通知] → [担当者へ転送]
  └── 一般質問   → [Knowledge Base 検索] → [回答メール送信]
```

### パターン 3: 競合モニタリング

```
[Cron: 毎日 9:00]
  ↓
[HTTP Request: 各競合サイトの RSS を取得]
  ↓
[AI Agent: 重要な更新を抽出・要約]
  ↓
[Supabase: competitor_reports テーブルに保存]
  ↓
[Slack: #competitor-updates に投稿]
```

---

## エラー処理とリトライ

```
ノード設定:
- On Error: Continue (エラーを無視して次のノードへ)
- On Error: Stop and Error (ワークフローを停止)
- On Error: Continue Error Output (エラーを別フローへ)

# リトライ設定
{
  "retryOnFail": true,
  "maxTries": 3,
  "waitBetweenTries": 1000  // 1秒待機
}
```

---

## このプロジェクト (自分株式会社) での活用

```
# ユースケース 1: AI大学コンテンツ自動更新
[Cron: 毎週月曜 9:00 JST]
  ↓
[HTTP Request: AI ニュースフィードを取得 (TechCrunch/VentureBeat)]
  ↓
[AI Agent (Claude): 新しい AI プロバイダーを特定・評価]
  ↓
[IF: スコア 7+ のプロバイダーあり]
  ↓ YES
[GitHub: Issue を作成 "AI大学: {name} を追加候補"]
  ↓
[Slack: PS#3 担当者に通知]

# ユースケース 2: WBS タスク自動レビュー
[Webhook: wbs_tasks テーブル変更検知]
  ↓
[Supabase: タスク詳細を取得]
  ↓
[AI Agent (Gemini): タスクを評価・承認/却下]
  ↓
[Supabase: ai_review_status を更新]
  ↓
[Slack: レビュー結果を通知]
```

---

## 本番環境 (Docker Compose)

```yaml
version: '3.8'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=your-domain.com
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://your-domain.com/
      - GENERIC_TIMEZONE=Asia/Tokyo
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=n8n
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=${DB_PASSWORD}
```

## クイックスタート (3 ステップ)

1. `docker run -p 5678:5678 docker.n8n.io/n8nio/n8n` で起動
2. `http://localhost:5678` → アカウント作成
3. 新規ワークフロー → ノードを追加 → Trigger を設定 → Active に切り替えて完了
$md$,
  'https://docs.n8n.io/hosting/',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
