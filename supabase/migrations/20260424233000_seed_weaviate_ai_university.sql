-- Session PS#3-S30: AI大学 155社化 — Weaviate 追加
-- Bob van Luijt (CEO) + Etienne Dilocker (CTO) が 2019 年オランダ・アムステルダムで創業。
-- OSS ベクターデータベースで GitHub 14,000+ stars / 5M+ ダウンロード / 2,000+ 本番導入企業。
-- $50M 累計調達 (IVP + Index Ventures + Battery Ventures) / 評価額 $500M+。
-- Serverless Cloud 無料14日トライアル → 従量課金 ($0.00975/100万 vector dimensions/月〜)。
-- 既存の Pinecone (pinecone) + Qdrant (qdrant) とは異なるマルチモーダル + AI-native 設計軸を埋める。
-- Step 0: 9/9 (OSS・マルチモーダル・組み込み Embeddings・AI Agents 機能・2,000+ 本番実績)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'weaviate',
  'overview',
  'Weaviate — AI-Native マルチモーダル ベクターデータベース',
  $md$
# Weaviate — The AI-Native Vector Database

2019 年オランダ・アムステルダム創業。**Bob van Luijt** (CEO) と **Etienne Dilocker** (CTO) が
「ベクター検索をアプリケーション開発者がそのまま使えるデータベース」として設計。

GitHub 14,000+ stars、5M+ ダウンロード、2,000+ 企業が本番で利用。
Zapier・Morningstar・StackOverflow・Instabase などが RAG・セマンティック検索に採用。

**AI-native 設計**が競合との最大の差別化点。
Embeddings 生成・Rerank・Agents 機能がデータベース内に組み込まれており、
外部 API を別途呼ぶことなく「データ保存 → 埋め込み → 検索 → 再ランク → 応答生成」を
一つのシステムで完結できる。

## 主要機能
- **マルチモーダル検索** — テキスト・画像・動画・音声を横断したセマンティック検索
- **組み込み Embeddings** — OpenAI / Cohere / Hugging Face などの Embedding モジュールを内蔵
- **Hybrid Search** — ベクター検索 (セマンティック) + BM25 (キーワード) の組み合わせ
- **Weaviate Agents** — データ操作・クエリ・変換を自律実行する AI エージェント (2025 新機能)
- **Generative Search** — RAG を DB クエリの一部として組み込み (外部 LLM 連携)
- **RBAC + マルチテナンシー** — エンタープライズグレードのアクセス制御

## 強み
- **OSS ファースト** — Apache 2.0 ライセンスで自己ホスト可・ベンダーロックイン回避
- Pinecone / Qdrant と異なり **マルチモーダルデータ** (テキスト以外) をネイティブサポート
- 組み込みモジュールで **外部 Embedding API 不要**な運用構成が可能
- 小規模から Fortune 500 まで対応するスケーラビリティ
$md$,
  'https://weaviate.io/',
  '2026-04-24',
  1
),

(
  'weaviate',
  'models',
  'Weaviate モジュール・デプロイ選択肢 (2026)',
  $md$
## Weaviate のモジュール (組み込み AI)

Weaviate は「モデル」ではなく「統合モジュール」を提供する。DB 内で AI 処理を完結させる。

## Embedding モジュール

| モジュール | 対応モデル | 用途 |
| :--- | :--- | :--- |
| **text2vec-openai** | text-embedding-3-small/large | テキスト埋め込み |
| **text2vec-cohere** | embed-v3 | 多言語テキスト |
| **text2vec-huggingface** | all-MiniLM など | OSS モデル |
| **multi2vec-clip** | OpenAI CLIP | テキスト+画像 |
| **multi2vec-google** | Vertex AI multimodal | マルチモーダル |

## Generative (RAG) モジュール

| モジュール | LLM | 説明 |
| :--- | :--- | :--- |
| **generative-openai** | GPT-4o / GPT-4 | DB クエリ結果を GPT に送信 |
| **generative-anthropic** | Claude 3.5 | 同上 (Anthropic 版) |
| **generative-google** | Gemini 1.5 Pro | 同上 (Google 版) |
| **generative-cohere** | Command R+ | 同上 (Cohere 版) |

## デプロイ選択肢

| 方式 | 説明 | 向き先 |
| :--- | :--- | :--- |
| **Serverless Cloud** | 完全マネージド SaaS | スタートアップ・個人開発 |
| **Enterprise Cloud** | 専用クラスター + SLA | 本番エンタープライズ |
| **自己ホスト (Docker)** | `docker compose up` で起動 | ハイブリッド / オンプレ |
| **Embedded** | Python アプリ内に組み込み | プロトタイプ |

## Weaviate Agents (2025〜)

```python
# Weaviate Agents: DB内でエージェントが自律実行
agent = client.agents.query.create(
    agent_id="my-agent",
    model=GenerativeConfig.openai("gpt-4o")
)
result = agent.run("今月の売上トップ10商品を教えて")
```
$md$,
  'https://weaviate.io/developers/weaviate',
  '2026-04-24',
  2
),

(
  'weaviate',
  'api',
  'Weaviate API 入門',
  $md$
## Weaviate API の始め方

```python
# pip install weaviate-client
import weaviate
from weaviate.classes.init import Auth
from weaviate.classes.config import Configure, Property, DataType

# Weaviate Cloud に接続
client = weaviate.connect_to_weaviate_cloud(
    cluster_url="https://your-cluster.weaviate.network",
    auth_credentials=Auth.api_key("your-api-key"),
    headers={"X-OpenAI-Api-Key": "your-openai-key"}  # Embedding モジュール用
)

# コレクション (旧: クラス) 作成
client.collections.create(
    name="Article",
    vectorizer_config=Configure.Vectorizer.text2vec_openai(),  # 自動 Embedding
    generative_config=Configure.Generative.openai("gpt-4o"),   # RAG 用
    properties=[
        Property(name="title", data_type=DataType.TEXT),
        Property(name="content", data_type=DataType.TEXT),
    ]
)

# データ挿入 (Embedding は自動生成)
articles = client.collections.get("Article")
articles.data.insert({"title": "AI News", "content": "Latest AI developments..."})

# セマンティック検索
response = articles.query.near_text(
    query="人工知能の最新動向",
    limit=5
)
for obj in response.objects:
    print(obj.properties["title"])

# RAG (Generative Search)
response = articles.generate.near_text(
    query="AI trends",
    limit=3,
    grouped_task="これらの記事の共通テーマを日本語で要約して"
)
print(response.generated)

client.close()
```

## 料金 (2026年4月時点)

| プラン | 料金 | ベクター次元 |
| :--- | :--- | :--- |
| **Free Trial** | 14 日間無料 | 制限あり |
| **Serverless Flex** | 従量課金 | $0.00975/100万次元/月 |
| **Enterprise** | 要問合せ | SLA 99.95% |

## クイックスタート

1. [cloud.weaviate.io](https://console.weaviate.cloud) でクラスター作成 (14 日無料)
2. `pip install weaviate-client` インストール
3. `weaviate.connect_to_weaviate_cloud(...)` で接続
4. コレクション作成 → データ投入 → セマンティック検索
$md$,
  'https://weaviate.io/developers/weaviate/client-libraries/python',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
