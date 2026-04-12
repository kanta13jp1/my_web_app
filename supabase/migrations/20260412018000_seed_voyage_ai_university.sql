-- Voyage AI コンテンツシード
-- AI大学: Voyage AI プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: Embedding専門企業としてRAG精度が最高クラス / voyage-3-large は MTEB ベンチマーク上位 / Reranker も提供でRAG精度をさらに向上 / OpenAI互換API

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('voyage', 'overview', 'Voyage AI 概要',
$$Voyage AI は2023年創業の**Embedding専門企業**。元 Meta・Google・Stanford の研究者が設立し、RAG (Retrieval-Augmented Generation) の精度を最大化することに特化したモデルを開発しています。MTEB (Massive Text Embedding Benchmark) で最上位クラスのスコアを達成しており、「検索精度が命」のエンタープライズ RAG 構築に採用されています。

## 特徴

- **Embedding 専門**: テキスト生成は行わず、高品質な Embedding 生成に集中
- **Reranker**: 検索結果を再ランキングして精度をさらに向上させる専用モデル
- **ドメイン特化**: Code・Finance・Law など専門領域向けモデルを提供
- **長コンテキスト**: voyage-3-large は最大 32K トークンのドキュメントを 1 回で Embedding 化
- **OpenAI 互換**: `text-embedding-ada-002` の置き換えとして即利用可能

## 強み

| 領域 | 内容 |
| :--- | :--- |
| **Embedding 精度** | MTEB ベンチマーク上位。OpenAI・Cohere より高精度なケース多数 |
| **Reranker** | 初回検索の上位候補を再スコアリングして最終精度を向上 |
| **ドメイン特化** | Code/Finance/Law/Medical 向け特化モデルで専門領域の精度が飛躍 |
| **長文 Embedding** | 32K コンテキストで長い文書を分割せずに 1 ベクトル化 |
| **コスト効率** | OpenAI `text-embedding-3-large` より安価で同等以上の精度 |

## RAG への影響

```text
一般的な RAG パイプライン:

Query → [Embedding] → [Vector Search] → Top-K Documents → [LLM] → Answer
                ↑                    ↑
         Voyage Embed で        Voyage Reranker で
         高精度ベクトル化        さらに精度向上
```

Voyage AI を使うことで、Vector Search の「検索漏れ」と「無関係文書の混入」を大幅に削減できます。$$,
'https://www.voyageai.com/', '2026-04-12', 1),

('voyage', 'models', 'Voyage AI — 利用可能モデル (2026)',
$$Voyage AI は Embedding モデルと Reranker モデルの2系統を提供しています。

## Embedding モデル

| モデル | 次元 | コンテキスト | 特徴 |
| :--- | :--- | :--- | :--- |
| **voyage-3-large** | 1024 | 32K | 最高精度汎用モデル。MTEB 上位クラス |
| **voyage-3** | 1024 | 32K | バランス型。高精度・低コスト |
| **voyage-3-lite** | 512 | 32K | 軽量・超高速。大量文書の一括処理 |
| **voyage-code-3** | 1024 | 32K | コード・技術文書特化 |
| **voyage-finance-2** | 1024 | 32K | 金融・財務文書特化 |
| **voyage-law-2** | 1024 | 32K | 法律・契約文書特化 |
| **voyage-multilingual-2** | 1024 | 32K | 多言語対応 (日本語含む) |

## Reranker モデル

| モデル | コンテキスト | 特徴 |
| :--- | :--- | :--- |
| **rerank-2** | 16K | 汎用 Reranker。最高精度 |
| **rerank-2-lite** | 16K | 高速・低コスト Reranker |

## MTEB ベンチマーク比較 (参考)

```text
Retrieval (BEIR benchmark, nDCG@10):

voyage-3-large:          65.1
text-embedding-3-large:  62.9
cohere-embed-v3:         63.8
voyage-multilingual-2:   62.0 (多言語対応で高スコア)
```

## 用途別推奨モデル

| 用途 | 推奨 Embedding | 推奨 Reranker |
| :--- | :--- | :--- |
| 汎用 RAG | voyage-3-large | rerank-2 |
| コード検索 | voyage-code-3 | rerank-2 |
| 金融文書 | voyage-finance-2 | rerank-2 |
| 法律文書 | voyage-law-2 | rerank-2 |
| 多言語・日本語 | voyage-multilingual-2 | rerank-2-lite |
| 大量文書・低コスト | voyage-3-lite | rerank-2-lite |$$,
'https://docs.voyageai.com/docs/embeddings', '2026-04-12', 2),

('voyage', 'api', 'Voyage AI API 入門',
$$## セットアップ

```bash
pip install voyageai
# または OpenAI 互換エンドポイントを使う場合
pip install openai
```

## Python SDK で Embedding 生成

```python
import voyageai

client = voyageai.Client(api_key="<VOYAGE_API_KEY>")

# 複数文書を一括 Embedding 化
documents = [
    "FlutterはGoogleが開発したクロスプラットフォームUIフレームワークです。",
    "SupabaseはオープンソースのFirebase代替サービスです。",
    "Dartは型安全なプログラミング言語です。",
    "Edge FunctionsはサーバーレスでAPIを提供する仕組みです。",
]

result = client.embed(
    documents,
    model="voyage-3-large",
    input_type="document",  # "document" or "query"
)

embeddings = result.embeddings
print(f"Embedding 数: {len(embeddings)}")
print(f"Embedding 次元: {len(embeddings[0])}")  # 1024
```

## Reranker で RAG 精度を向上

```python
import voyageai

client = voyageai.Client(api_key="<VOYAGE_API_KEY>")

# Step 1: ベクトル検索で上位20件を取得 (粗い検索)
query = "FlutterでのSupabase認証の実装方法"
top_20_documents = vector_db.search(query, top_k=20)  # 仮の関数

# Step 2: Reranker で上位3件に絞り込む (精密な再ランキング)
reranking = client.rerank(
    query=query,
    documents=[doc["text"] for doc in top_20_documents],
    model="rerank-2",
    top_k=3,
)

# 最終的な上位3件を LLM に渡す
best_docs = [top_20_documents[r.index]["text"] for r in reranking.results]
print(f"最も関連性が高い文書:\n{best_docs[0]}")
```

## Supabase pgvector と組み合わせた完全な RAG

```python
import voyageai
from supabase import create_client

voyage = voyageai.Client(api_key="<VOYAGE_API_KEY>")
supabase = create_client("<SUPABASE_URL>", "<SUPABASE_KEY>")

def embed_and_store(text: str, metadata: dict):
    """文書をEmbeddingして Supabase に保存"""
    result = voyage.embed([text], model="voyage-3-large", input_type="document")
    embedding = result.embeddings[0]

    supabase.table("documents").insert({
        "content": text,
        "embedding": embedding,
        "metadata": metadata,
    }).execute()

def rag_search(query: str, top_k: int = 5) -> list[str]:
    """クエリに関連する文書を検索"""
    # クエリを Embedding 化
    result = voyage.embed([query], model="voyage-3-large", input_type="query")
    query_embedding = result.embeddings[0]

    # pgvector でコサイン類似度検索
    response = supabase.rpc("match_documents", {
        "query_embedding": query_embedding,
        "match_count": 20,  # 粗い検索で20件取得
    }).execute()

    # Reranker で精密に絞り込み
    docs = [r["content"] for r in response.data]
    reranked = voyage.rerank(query=query, documents=docs, model="rerank-2", top_k=top_k)

    return [docs[r.index] for r in reranked.results]

# 使用例
results = rag_search("FlutterでのState管理のベストプラクティスは？")
for i, doc in enumerate(results, 1):
    print(f"{i}. {doc[:100]}...")
```

## OpenAI 互換 API

```python
from openai import OpenAI

# text-embedding-ada-002 の置き換えとして即利用可能
client = OpenAI(
    api_key="<VOYAGE_API_KEY>",
    base_url="https://api.voyageai.com/v1"
)

response = client.embeddings.create(
    model="voyage-3",
    input=["日本語テキストのEmbeddingテスト"],
)

print(f"Embedding 次元: {len(response.data[0].embedding)}")
```

## 料金 (2026年4月時点, USD)

| モデル | 料金 (1M tokens) |
| :--- | :--- |
| **voyage-3-large** | $0.18 |
| **voyage-3** | $0.06 |
| **voyage-3-lite** | $0.02 |
| **voyage-code-3** | $0.18 |
| **voyage-finance-2** | $0.12 |
| **voyage-law-2** | $0.12 |
| **voyage-multilingual-2** | $0.12 |

| Reranker | 料金 (1K queries) |
| :--- | :--- |
| **rerank-2** | $0.05 |
| **rerank-2-lite** | $0.02 |

- **無料枠**: 月 50M tokens まで無料 (新規登録)
- **OpenAI `text-embedding-3-large` ($0.13/1M) より安価で高精度**$$,
'https://docs.voyageai.com/docs/quickstart', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Voyage AI 追加 (27社目)',
  'Voyage AI を AI大学プロバイダーとして追加。Embedding専門企業としてvoyage-3-large/code/finance/law特化モデル・Rerankerによる2段階RAG精度向上・Supabase pgvectorとの完全統合例を収録。AI大学プロバイダー数 26社→27社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
