-- PS#3 S64: AI大学 223→224社化 — Dust 追加
-- Dust: エンタープライズAIエージェントプラットフォーム / カスタムAIアシスタント / Slack/Notion統合

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dust',
  'overview',
  'Dust — エンタープライズAIエージェントプラットフォーム (カスタムAssistant/社内知識統合/Slack/Notion連携)',
  $$## Dust — エンタープライズAIエージェントプラットフォーム

**カテゴリ**: Enterprise AI Agent / Knowledge Management / Workflow Automation
**設立**: 2022年 / 本社: Paris, France / 資金調達: ~$16M (Sequoia / Y Combinator S22)
**特徴**: 社内ドキュメント・Slack・Notion・CRMを学習したカスタムAIアシスタントを企業が構築・デプロイできるプラットフォーム
**ユーザー**: エンジニアリングチーム / カスタマーサポート / 営業チーム / HR / 中規模〜大企業
**評価**: 8/9

### 概要
Dust は **「企業固有の知識を持つAIアシスタントを、コードなしで構築・展開」** するプラットフォーム。Slack やメールで届く質問に AI が社内 Wiki・Notion・Confluence・Salesforce などのデータを参照しながら自動回答する。OpenAI の ChatGPT Enterprise や Anthropic の Claude for Enterprise と競合するが、**マルチモデル対応** (GPT-4o / Claude 3.5 / Gemini 1.5) と **データソース統合の深さ** で差別化。フランス発で欧州プライバシー規制 (GDPR) への対応が強い。

### 主な機能

**カスタム AI アシスタント (Agents)**
- ノーコードで業務特化エージェントを構築
  - 例: 「新入社員オンボーディングBot」= 社内規定PDF + Notion HR ページ + Slack #onboarding を学習
  - 例: 「テクニカルサポートBot」= GitHub Issues + Confluence + Slack #tech-support を学習
  - 例: 「営業支援Bot」= Salesforce CRM + 提案書テンプレ + 競合情報 を学習
- エージェントをSlack / Webサイト / アプリに1行コードで埋め込み

**データソース統合 (20+)**
| カテゴリ | 対応サービス |
|---------|------------|
| ドキュメント | Notion / Confluence / Google Drive / SharePoint |
| コミュニケーション | Slack / Microsoft Teams / Intercom |
| コード/開発 | GitHub / GitLab / Linear / Jira |
| CRM/営業 | Salesforce / HubSpot |
| ファイル | PDF / CSV / Web URL クローリング |

**マルチモデル対応**
- GPT-4o / GPT-4 Turbo (OpenAI)
- Claude 3.5 Sonnet / Claude 3 Opus (Anthropic)
- Gemini 1.5 Pro (Google)
- Mistral Large (欧州モデル)
- ユーザーが各アシスタントごとにモデルを選択可能

**セキュリティ**
- データはDust環境内で処理 (LLMプロバイダーへの学習利用なし)
- GDPR準拠 / SOC2 Type II (取得中) / EU データ主権
- Role-based access control (チーム / 部門ごとのアクセス制御)

### アーキテクチャ概念
```
[データソース]                [Dust Platform]           [エンドユーザー]
Notion ──────┐               ┌──────────────┐
Slack ───────┼──→ Retrieval  │  Custom       │→ Slack Bot
GitHub ──────┤   Pipeline    │  Agent        │→ Web Widget
Salesforce ──┘               │  (LLM + RAG)  │→ API
                              └──────────────┘
                                     ↑
                            GPT-4o / Claude / Gemini
```

### 競合との差別化
| 項目 | Dust | Notion AI | ChatGPT Enterprise | Glean |
|------|------|----------|-------------------|-------|
| カスタムエージェント | ✅ 複数 | ❌ | △ | △ |
| マルチモデル | ✅ | ❌ | ❌ (GPT-4のみ) | ❌ |
| データソース統合 | 20+ | Notionのみ | 有限 | 多数 |
| GDPR準拠 | ✅ EU製 | △ | △ | △ |
| 価格 | 中 | 低 | 高 | 高 |
| エージェント構築 | ノーコード | ❌ | ❌ | ❌ |

### 導入コスト
- **Free**: 5ユーザー / 1エージェント / 基本データソース
- **Pro**: 月$29/ユーザー / 無制限エージェント / 全データソース / 優先サポート
- **Enterprise**: カスタム / SSO / SAML / 専任CSM / SLA / オンプレ対応$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dust',
  'api',
  'Dust API — カスタムエージェント呼び出し・データソース管理・Slack Bot統合 (Python/TypeScript)',
  $$## Dust API

### 概要
Dust は REST API + TypeScript SDK を提供。カスタムエージェントをプログラムから呼び出し、データソースを管理できる。

### セットアップ
```bash
# Dust → Settings → API Keys でキー取得
export DUST_API_KEY="your_api_key_here"
export DUST_WORKSPACE_ID="your_workspace_id"
export DUST_BASE="https://dust.tt/api/v1"

# TypeScript SDK
npm install @dust-tt/client
```

### エージェント呼び出し (Python)
```python
import requests
import os

DUST_API_KEY = os.environ["DUST_API_KEY"]
DUST_WS_ID = os.environ["DUST_WORKSPACE_ID"]
DUST_BASE = os.environ["DUST_BASE"]

HEADERS = {
    "Authorization": f"Bearer {DUST_API_KEY}",
    "Content-Type": "application/json",
}

def create_conversation(agent_id: str, message: str) -> dict:
    """Dustカスタムエージェントに質問を投げる"""
    payload = {
        "visibility": "unlisted",
        "title": None,
        "message": {
            "content": message,
            "mentions": [{"configurationId": agent_id}],
            "context": {
                "timezone": "Asia/Tokyo",
                "username": "api_user",
                "fullName": "API User",
                "email": "api@example.com",
                "profilePictureUrl": None,
                "origin": "api",
            },
        },
    }
    resp = requests.post(
        f"{DUST_BASE}/w/{DUST_WS_ID}/assistant/conversations",
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

def get_conversation_answer(conversation_id: str, message_id: str) -> str:
    """エージェントの回答を取得 (ポーリング)"""
    import time
    for _ in range(30):  # 最大30秒待機
        resp = requests.get(
            f"{DUST_BASE}/w/{DUST_WS_ID}/assistant/conversations/{conversation_id}",
            headers=HEADERS,
        )
        resp.raise_for_status()
        conv = resp.json()["conversation"]
        for content in conv.get("content", []):
            for msg in content:
                if msg.get("type") == "agent_message" and msg.get("status") == "succeeded":
                    return msg.get("content", "")
        time.sleep(1)
    return ""

# 社内ナレッジBot呼び出し例
result = create_conversation(
    agent_id="hr-assistant",  # Dust管理画面で設定したエージェントID
    message="新入社員の有給休暇申請の手順を教えてください",
)
conv_id = result["conversation"]["sId"]
answer = get_conversation_answer(conv_id, "")
print(f"回答: {answer}")
```

### TypeScript SDK (Next.js / Deno)
```typescript
import DustAPI from "@dust-tt/client";

const dust = new DustAPI(
  { url: "https://dust.tt" },
  { workspaceId: Deno.env.get("DUST_WORKSPACE_ID")!, apiKey: Deno.env.get("DUST_API_KEY")! },
  console
);

// エージェント一覧取得
const agentConfigurations = await dust.getAgentConfigurations();
if (agentConfigurations.isOk()) {
  for (const agent of agentConfigurations.value) {
    console.log(`${agent.name} (${agent.sId}): ${agent.description}`);
  }
}

// 会話作成 + ストリーミング回答取得
const conversation = await dust.createConversation({
  title: "API Test",
  visibility: "unlisted",
  message: {
    content: "自分株式会社の競合分析をまとめてください",
    mentions: [{ configurationId: "competitive-intelligence" }],
    context: {
      timezone: "Asia/Tokyo",
      username: "system",
      fullName: "System",
      email: "system@jibun.co.jp",
      profilePictureUrl: null,
      origin: "api",
    },
  },
});

if (conversation.isOk()) {
  console.log("会話ID:", conversation.value.conversation.sId);
}
```

### Slack Bot 統合 (Dust × Slack)
```
Dust管理画面 → Connections → Slack → "Add to Slack" ボタン
→ Slack ワークスペースに @dust ボットが追加される

使い方:
  @dust [エージェント名] [質問]
  例: @dust hr-bot 有給申請のフローを教えて
  例: @dust sales-bot 昨月の商談成約率は?

Dust がSlack メッセージを受信
→ 該当エージェントが学習済みデータソースを検索
→ 引用元URLを付けて返答
→ スレッドに投稿
```

### GHA × Dust ナレッジ自動同期
```yaml
# .github/workflows/dust-knowledge-sync.yml
# 毎週月曜 08:30 JST → Supabase ai_university_content → Dust データソースに同期
steps:
  - name: Export AI university content to Dust
    env:
      DUST_API_KEY: ${{ secrets.DUST_API_KEY }}
      DUST_WORKSPACE_ID: ${{ secrets.DUST_WORKSPACE_ID }}
      SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
    run: python scripts/sync_ai_university_to_dust.py
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dust',
  'models',
  'Dust AI技術詳細 — RAGアーキテクチャ + マルチモデルオーケストレーション + Sequoia/YC資金調達',
  $$## Dust AI 技術詳細

### RAG (Retrieval-Augmented Generation) パイプライン
```
[データソース取り込み]
Notion / Slack / GitHub 等
       ↓
Document Chunking:
  - ドキュメントを意味単位でチャンク分割 (500〜1,500トークン)
  - メタデータ付与 (source / author / timestamp / URL)
       ↓
Embedding Generation:
  - text-embedding-3-large (OpenAI) でベクトル化
  - Dust 専用ベクトルDB (Weaviate ベース) に格納
       ↓

[クエリ時]
ユーザー質問
       ↓
Query Embedding: 質問をベクトル化
       ↓
Semantic Search: コサイン類似度でTop-K チャンクを取得
       ↓
Reranking: Cross-encoder でスコア再計算
       ↓
LLM (GPT-4o / Claude 3.5 / etc.):
  取得チャンク + 質問 + システムプロンプト → 回答生成
       ↓
出力: 回答 + 引用元ドキュメントリスト
```

### マルチモデルオーケストレーション
```
エージェント設定例:
  名前: competitive-intelligence
  モデル: claude-sonnet-4-6  ← 高精度な分析が必要な場合
  データソース: [competitor-reports, market-research, slack-#strategy]
  プロンプト: "競合分析の専門家として、最新の市場データを参照しながら..."

別エージェント設定:
  名前: quick-faq-bot
  モデル: gpt-4o-mini  ← 低コスト・高速が必要な場合
  データソース: [faq-docs, product-docs]
  プロンプト: "ユーザーサポートの担当者として..."

→ タスク性質に応じて最適なモデルを使い分け
→ Claude の長文推論 + Gemini の多言語 + GPT-4の汎用性 を並用
```

### 投資家・エコシステム
- **YC S22**: Y Combinator バッチ参加 (2022年)
- **Sequoia Capital**: Series A リード (欧州 Sequoia)
- **設立者**: Stanislas Polu (元OpenAI / Stripe), Gabriel Hubert (元Stripe)
- **競合比較**:
  - Glean ($2.2B評価): 検索特化型 / Dust: エージェント特化型
  - ChatGPT Enterprise: Microsoft依存 / Dust: マルチモデル自由度
  - Notion AI: Notionのみ / Dust: 20+データソース統合

### Dust の技術的優位性 (2026年)
1. **マルチモデル + ノーコード**: 非技術者でも企業固有エージェントを構築
2. **データプライバシー**: EUデータ主権 + LLMへの学習利用なし保証
3. **深いSlack統合**: @メンション一発でエージェント呼び出し (他社にない体験)
4. **引用元の透明性**: 全回答に元ドキュメントURLを自動付与 (ハルシネーション防止)

### 自分株式会社での活用可能性
- **AI大学Botの基盤**: Dust エージェント (データ: ai_university_content) → Slack/Webに「AI大学Bot」を即座にデプロイ
- **競合情報Bot**: Dust に competitor_features + 競合レポートを学習 → 「○○と比較してどうですか?」に即回答
- **社内ナレッジBot**: CLAUDE.md + ROADMAP + memory/ → 新入社員オンボーディング自動化
- **カスタマーサポートBot**: Supabase FAQ + docs/ → サポートチケット自動回答
- **マルチモデル実験**: Claude/GPT-4/Gemini を Dust 上でA/Bテスト → 最適モデル選定$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 223→224社化: Dust 追加',
  'PS#3 S64。Dust (エンタープライズAIエージェントプラットフォーム/カスタムAssistant/20+データソース統合/Slack×Notion×GitHub連携/マルチモデル(GPT-4o/Claude/Gemini)/GDPR準拠/YC S22/Sequoia/$16M/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
