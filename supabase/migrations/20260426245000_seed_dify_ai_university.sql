-- PS#3 S70: AI大学 235→236社化 — Dify 追加
-- Dify: OSS LLMアプリ開発プラットフォーム / RAGパイプライン / エージェント / GitHub 70k+ stars / Sequoia $12M

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dify',
  'overview',
  'Dify — OSS LLMアプリ開発プラットフォーム (RAGパイプライン+エージェント+API / GitHub 70k+ / Sequoia $12M)',
  $$## Dify — オープンソース LLMアプリ開発プラットフォーム

**カテゴリ**: LLM Application Platform / RAG Pipeline / Agent Builder / Open Source
**開発元**: LangGenius Inc. / 本社: San Francisco, CA
**設立**: 2023年 / 創業者: 熊少峰 (Shao-Feng Xiong) 他
**資金調達**: $12M Series A (2024年) / 投資家: Sequoia Capital (中国) / Source Code Capital
**GitHub**: 70,000+ stars (2025年時点) / Apache 2.0 ライセンス
**提供形態**: Cloud (dify.ai) / Self-hosted (Docker) / Dify Enterprise
**評価**: 9/9

### 概要
Dify は **「LLMアプリをノーコード〜ローコードで開発・デプロイ・運用する」** ための統合プラットフォーム。RAGパイプライン・エージェントワークフロー・プロンプト管理・APIホスティングを一括提供する。

GitHubスター数70,000超は2024年のAI OSS最速成長プロジェクトの一つ。特に **中国・日本・東南アジア** での採用が多く、「企業内AI活用をLangChainより簡単に始められる」と評される。日本語UI対応・日本語ドキュメント充実が他OSS LLMプラットフォームとの差別化要因。

### 主な機能

**Visual Workflow Builder (視覚的ワークフロー)**
- ノードベースのドラッグ&ドロップUI
- LLMコール / 変数変換 / 条件分岐 / ループ を視覚的に接続
- テンプレート: チャットボット / RAG知識ベース / エージェント / テキスト生成

**RAGパイプライン (ナレッジベース)**
- PDF / Word / Web URL / Notion / GitHub など多様なソースを取り込み
- チャンク分割・埋め込み生成・ベクターDB管理を自動処理
- 対応ベクターDB: Pinecone / Weaviate / Qdrant / Milvus / pgvector
- ハイブリッド検索 (キーワード + ベクター)

**エージェントオーケストレーション**
- ReActエージェント / Function Callingエージェント を設定なしで構築
- ツール統合: Web検索 / 計算機 / 天気 / カスタムAPI (OpenAPI仕様書取り込み)
- マルチエージェント: 複数エージェントの連携ワークフロー

**プロンプト管理**
- バージョン管理付きプロンプト (git likeな比較・ロールバック)
- A/Bテスト: 複数プロンプトのパフォーマンス比較
- プロンプトオーケストレーション: System / User / Assistant ロールを視覚的編集

**API / Embed**
- 作成したアプリを REST API として公開 (1クリック)
- Webサイト埋め込み用 iFrame / Chatbot Widget
- Streaming対応 (Server-Sent Events)

### サポートLLM (30+)
| プロバイダー | モデル |
|------------|--------|
| OpenAI | GPT-4o / GPT-4 Turbo / GPT-3.5 |
| Anthropic | Claude 3.5 Sonnet / Claude 3 Opus |
| Google | Gemini 1.5 Pro / Flash |
| Mistral | Mistral Large / 7B |
| ローカル | Ollama / LM Studio 経由でローカルモデル |
| Azure OpenAI | Azure 経由での OpenAI モデル |
| Cohere | Command R+ |

### セルフホスト vs クラウド

| 項目 | Cloud (dify.ai) | Self-hosted (Docker) |
|------|----------------|---------------------|
| 初期費用 | 無料〜$59/月 | サーバー代のみ |
| データ保管 | Difyサーバー | 自社 |
| カスタマイズ | 制限あり | 完全自由 |
| 運用工数 | なし | 必要 |
| 推奨用途 | PoC / 小規模 | 企業本番 / 機密データ |

### 導入コスト (Cloud)
- **Sandbox (無料)**: 200メッセージ/月 / 1ワークスペース / 5アプリ / 1ナレッジベース
- **Professional**: 月$59 / 5000メッセージ / 無制限アプリ / 5ナレッジベース
- **Team**: 月$159 / チームメンバー複数 / 高度な権限管理
- **Self-hosted**: 無料 (Apache 2.0) / Enterprise版は有償

### 自分株式会社での活用可能性
- **CS自動化**: `get-support-tickets` EF → Dify RAG + Claude → 自動返信品質向上
- **AI大学コンテンツ生成**: Dify ワークフロー → Webスクレイプ → プロバイダー説明自動生成
- **内部知識ベース**: docs/ ディレクトリを Dify RAG に取り込み → 社内AI検索ツール構築$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dify',
  'api',
  'Dify API — LLMアプリ呼び出し / RAG検索 / ワークフロー実行 (Python/TypeScript/Supabase EF統合)',
  $$## Dify API / 統合

### 概要
Dify でビルドしたアプリは REST API として公開できる。APIキーはアプリごとに発行される。

### セットアップ
```bash
# Cloud版
DIFY_API_URL="https://api.dify.ai/v1"
DIFY_API_KEY="app-xxxxxxxxxxxxxxxxxxxx"

# Self-hosted版
DIFY_API_URL="https://your-dify-domain.com/v1"
DIFY_API_KEY="app-xxxxxxxxxxxxxxxxxxxx"
```

### チャットアプリ呼び出し (Python)
```python
import os
import requests

DIFY_API_URL = os.environ["DIFY_API_URL"]
DIFY_API_KEY = os.environ["DIFY_API_KEY"]

HEADERS = {
    "Authorization": f"Bearer {DIFY_API_KEY}",
    "Content-Type": "application/json",
}

def chat_with_dify(
    user_message: str,
    conversation_id: str = "",
    user_id: str = "anonymous",
) -> dict:
    """Dify チャットアプリにメッセージを送信"""
    resp = requests.post(
        f"{DIFY_API_URL}/chat-messages",
        headers=HEADERS,
        json={
            "inputs": {},
            "query": user_message,
            "response_mode": "blocking",  # または "streaming"
            "conversation_id": conversation_id,
            "user": user_id,
        },
    )
    resp.raise_for_status()
    return resp.json()

# CS チケット自動返信
ticket = {
    "user_id": "user_123",
    "message": "ログインできません。パスワードリセットの方法を教えてください。",
}
result = chat_with_dify(
    user_message=ticket["message"],
    user_id=ticket["user_id"],
)
print(f"回答: {result['answer']}")
print(f"会話ID: {result['conversation_id']}")  # 続きの会話で使用
```

### RAGナレッジベース検索
```python
def search_knowledge_base(
    dataset_id: str,
    query: str,
    top_k: int = 5,
) -> list[dict]:
    """Dify ナレッジベースをセマンティック検索"""
    resp = requests.post(
        f"{DIFY_API_URL}/datasets/{dataset_id}/retrieve",
        headers=HEADERS,
        json={
            "query": query,
            "retrieval_model": {
                "search_type": "hybrid_search",
                "top_k": top_k,
                "score_threshold_enabled": True,
                "score_threshold": 0.5,
            },
        },
    )
    resp.raise_for_status()
    return resp.json().get("records", [])

# docs/ ディレクトリをナレッジベースとして検索
results = search_knowledge_base(
    dataset_id="your-dataset-uuid",
    query="Edge Function の作り方",
    top_k=3,
)
for r in results:
    print(f"[スコア {r['score']:.2f}] {r['segment']['content'][:100]}...")
```

### ワークフロー実行 (Completion API)
```python
def run_workflow(inputs: dict, user_id: str = "system") -> str:
    """Dify ワークフローを実行して最終出力を返す"""
    resp = requests.post(
        f"{DIFY_API_URL}/workflows/run",
        headers=HEADERS,
        json={
            "inputs": inputs,
            "response_mode": "blocking",
            "user": user_id,
        },
    )
    resp.raise_for_status()
    data = resp.json()
    return data["data"]["outputs"].get("text", "")

# AI大学コンテンツ自動生成ワークフロー
content = run_workflow(
    inputs={
        "provider_name": "新しいAIプロバイダー",
        "provider_url": "https://example.com",
        "category": "動画生成",
    }
)
print(content)
```

### Supabase Edge Function 統合
```typescript
// supabase/functions/dify-cs-auto-reply/index.ts
const DIFY_API_URL = Deno.env.get("DIFY_API_URL")!;
const DIFY_API_KEY = Deno.env.get("DIFY_API_KEY")!;

Deno.serve(async (req: Request) => {
  const { ticket_id, message, user_id } = await req.json();

  const difyResp = await fetch(`${DIFY_API_URL}/chat-messages`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${DIFY_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      inputs: {},
      query: message,
      response_mode: "blocking",
      user: user_id ?? "anonymous",
    }),
  });

  if (!difyResp.ok) {
    return new Response(
      JSON.stringify({ error: "Dify API error" }),
      { status: difyResp.status, headers: { "Content-Type": "application/json" } },
    );
  }

  const { answer, conversation_id } = await difyResp.json();
  return new Response(
    JSON.stringify({ ticket_id, answer, conversation_id }),
    { headers: { "Content-Type": "application/json" } },
  );
});
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dify',
  'models',
  'Dify 技術詳細 — アーキテクチャ / LangChain比較 / セルフホスト構成 / 日本語エンタープライズ導入事例',
  $$## Dify 技術詳細

### アーキテクチャ概要

```
[Dify システムアーキテクチャ]

フロントエンド (Next.js):
  ├── Studio: ワークフロービルダー / プロンプトエンジニア UI
  ├── Web App: 公開されたアプリのエンドユーザー画面
  └── Console: 管理・分析・モデル設定

バックエンド (Python / Flask):
  ├── API Server: REST API エンドポイント
  ├── Worker: 非同期タスク処理 (Celery)
  ├── RAG Pipeline: ドキュメント取り込み・埋め込み生成
  └── Tool Registry: 外部ツール統合管理

データストア:
  ├── PostgreSQL: アプリ設定 / 会話履歴 / ユーザーデータ
  ├── Redis: セッション / キャッシュ / ジョブキュー
  ├── Weaviate / Qdrant (選択式): ベクターデータ
  └── S3/MinIO: アップロードファイル / 画像

デプロイ:
  Docker Compose 1コマンドで全サービス起動
  Kubernetes Helm chart も公式提供
```

### LangChain との比較

| 項目 | Dify | LangChain |
|------|------|----------|
| 対象ユーザー | **ノーコード〜ローコード** (プロダクトチーム) | **コード中心** (MLエンジニア) |
| UI | ✅ GUI ビルダー | ❌ コードのみ |
| RAGパイプライン | ✅ ノーコード設定 | △ コード実装必要 |
| プロダクション運用 | ✅ 組み込み (監視/ログ/A-B) | △ 別途 LangSmith 等が必要 |
| カスタマイズ | △ (制限あり) | ✅ 完全自由 |
| セルフホスト | ✅ Docker 1コマンド | ✅ (インフラ自前) |
| 日本語サポート | ✅ UI/ドキュメント日本語 | △ (コミュニティ翻訳) |
| 学習コスト | 低 (1〜2時間で動作確認) | 高 (数日〜数週間) |

### Docker セルフホスト構成 (本番推奨)
```yaml
# docker-compose.yaml (簡略版)
version: '3'
services:
  api:
    image: langgenius/dify-api:latest
    environment:
      - SECRET_KEY=your-secret-key
      - DB_HOST=db
      - REDIS_HOST=redis
      - VECTOR_STORE=weaviate
    depends_on: [db, redis, weaviate]

  web:
    image: langgenius/dify-web:latest
    environment:
      - CONSOLE_API_URL=https://your-domain.com

  db:
    image: postgres:15-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:6-alpine

  weaviate:
    image: semitechnologies/weaviate:latest

  nginx:
    image: nginx:latest
    ports:
      - "80:80"
      - "443:443"
    # SSL証明書 (Let's Encrypt) の設定

# 起動コマンド
# docker compose up -d
```

### 日本企業での採用事例

Dify は日本国内でも急速に普及している:
- **大手製造業**: 社内技術文書 (PDF数万件) をRAGに取り込み → 設計者向けAI質問応答システム
- **EC企業**: 商品カタログ + FAQ をナレッジベース化 → CS問い合わせ自動回答率70%達成
- **SIer複数社**: 顧客向けAI導入PoC のデファクト基盤として採用
- **スタートアップ**: LangChain の代替として「開発速度3倍」との評価

### 自分株式会社での実装提案

```
現状の CS フロー:
  サポートチケット → get-support-tickets EF → Claude Code スケジュールタスク → reply-support-request EF

Dify 統合後:
  サポートチケット → Dify RAG (docs/ + FAQ知識ベース) → 高品質自動回答 → reply-support-request EF
  → Claude Code は「エスカレーション判断のみ」に集中
  → Claude API コスト 60% 削減見込み (FAQ系は RAG で処理)
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 235→236社化: Dify 追加',
  'PS#3 S70。Dify (OSS LLMアプリ開発プラットフォーム/RAGパイプライン/エージェントビルダー/Visual Workflow/30+LLM統合/GitHub 70k+ stars/Sequoia $12M/日本語対応/セルフホスト可能/9/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
