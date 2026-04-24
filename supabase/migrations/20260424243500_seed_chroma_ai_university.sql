-- Session PS#3-S33: AI大学 162社化 — Chroma 追加
-- Jeff Huber + Anton Troynikov が 2022 年に創業した OSS ベクターデータベース。
-- $18M seed (2023-04 / Amplify Partners 主導)。
-- "Developer-first" 設計: pip install chromadb → 3行でベクターストア起動。
-- 2026 年 Rust コア書き換えで 4× 速度向上 / Chroma Cloud GA。
-- LangChain・LlamaIndex の RAG チュートリアルで最頻出の入門 vector DB。
-- 既存 160 社の「vector DB」軸: Weaviate (エンタープライズ) と対比して「超シンプル OSS」軸を確立。
-- Step 0: 8/9 (GitHub 20k+ stars / LangChain 公式統合 / Rust 4× / Cloud GA / $18M seed)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'chroma',
  'overview',
  'Chroma — Developer-First オープンソースベクターデータベース',
  $md$
# Chroma — Open-Source Vector Database for AI

2022 年創業。**Jeff Huber** (元 Google YouTube / Instagram CTO 経験)
と **Anton Troynikov** が「あらゆる開発者が LLM アプリに
ベクター検索を組み込める」ことを目標に設立。

`pip install chromadb` の 1 行インストールと **3 行のコード** で
完全なベクターストアが起動するシンプルさが最大の特徴。
LangChain・LlamaIndex の公式チュートリアルで最も頻繁に使われる入門 vector DB として
**GitHub 20,000+ スター** を獲得し、RAG 開発のデファクト入り口となった。

2023 年 4 月に **Amplify Partners** 主導で **$18M シード**調達。
2026 年に **Rust コア書き換え** (4× 速度向上) を完了し、
**Chroma Cloud** を GA リリース。

## 動作モード

| モード | 説明 | 用途 |
| :--- | :--- | :--- |
| **In-Memory** | プロセス内メモリで動作・永続化なし | プロトタイピング・テスト |
| **Persistent** | ローカルディスクに保存 | 小〜中規模本番 |
| **Chroma Cloud** | マネージドクラウド API | スケール本番 |

## 強み

- **ゼロ設定** — `chromadb.Client()` 一行で起動・設定不要
- **Python-first** — Pythonic API・pandas との親和性高
- **多様な embedding 関数** — OpenAI / Cohere / HuggingFace / Nomic etc. をプラグイン対応
- **メタデータフィルタリング** — `where={"category": "tech"}` でベクター検索 + 属性絞り込み
- **完全 OSS** — Apache 2.0 / self-host 無料
$md$,
  'https://www.trychroma.com/',
  '2026-04-24',
  1
),

(
  'chroma',
  'models',
  'Chroma Cloud プラン・機能一覧 (2026)',
  $md$
## Chroma Cloud 料金プラン

| プラン | 月額 | ストレージ | 用途 |
| :--- | :--- | :--- | :--- |
| **Free** | $0 | 1M embeddings | プロトタイプ・個人 |
| **Team** | $100〜 | 従量 | スタートアップ本番 |
| **Enterprise** | 要相談 | BYOC 対応 | 大規模・コンプライアンス |

> 新規アカウントに $5 クレジット付与

## 主要機能

| 機能 | 説明 |
| :--- | :--- |
| **Collection** | ドキュメント + embedding + メタデータの論理グループ |
| **HNSW インデックス** | 高速近似最近傍検索 (ANN) |
| **メタデータフィルタ** | `where` / `where_document` での属性絞り込み |
| **多様距離関数** | L2 / Inner Product / Cosine |
| **Embedding 関数** | 30+ のプロバイダーをプラグイン |

## embedding 関数サポート

| プロバイダー | クラス |
| :--- | :--- |
| **OpenAI** | `OpenAIEmbeddingFunction` |
| **Cohere** | `CohereEmbeddingFunction` |
| **Nomic AI** | `NomicEmbeddingFunction` |
| **HuggingFace** | `HuggingFaceEmbeddingFunction` |
| **Sentence Transformers** | `SentenceTransformerEmbeddingFunction` (ローカル無料) |

## 2026 年の主要アップデート

- **Rust コア書き換え**: 4× スループット向上・メモリ使用量 50% 削減
- **Chroma Cloud GA**: BYOC (自社クラウド持ち込み) 対応エンタープライズプラン
- **分散クエリ**: 複数ノードへの水平スケールアウト対応
$md$,
  'https://docs.trychroma.com/',
  '2026-04-24',
  2
),

(
  'chroma',
  'api',
  'Chroma API 入門',
  $md$
## Chroma の始め方

### インストール & 基本操作 (Python)

```python
# pip install chromadb

import chromadb

# ローカル persistent クライアント
client = chromadb.PersistentClient(path="./chroma_db")

# コレクション作成 (= テーブルに相当)
collection = client.get_or_create_collection(
    name="ai_documents",
    metadata={"hnsw:space": "cosine"}  # 距離関数: cosine
)

# ドキュメントを追加 (embedding は Chroma が自動生成)
collection.add(
    documents=["Nomic AI は embeddings API を提供", "Chroma は vector DB"],
    metadatas=[{"category": "ai"}, {"category": "database"}],
    ids=["doc1", "doc2"]
)

# 類似検索
results = collection.query(
    query_texts=["embeddings の使い方"],
    n_results=2,
    where={"category": "ai"}  # メタデータフィルタ
)
print(results["documents"])
```

### OpenAI Embedding + Chroma

```python
import chromadb
from chromadb.utils import embedding_functions

# OpenAI embedding 関数を使用
openai_ef = embedding_functions.OpenAIEmbeddingFunction(
    api_key="your-openai-api-key",
    model_name="text-embedding-3-small"
)

collection = client.get_or_create_collection(
    name="rag_docs",
    embedding_function=openai_ef
)
```

### LangChain との統合 (RAG)

```python
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain.chains import RetrievalQA
from langchain_openai import ChatOpenAI

# ベクターストアを構築
vectorstore = Chroma.from_documents(
    documents=docs,                      # LangChain Document リスト
    embedding=OpenAIEmbeddings(),
    persist_directory="./chroma_db"
)

# RAG チェーン
qa_chain = RetrievalQA.from_chain_type(
    llm=ChatOpenAI(model="gpt-4o"),
    retriever=vectorstore.as_retriever(search_kwargs={"k": 3})
)

answer = qa_chain.invoke({"query": "AI大学の登録社数は？"})
```

## クイックスタート

1. `pip install chromadb` でインストール
2. `chromadb.PersistentClient(path="./db")` でローカル起動
3. `collection.add(documents=[...])` でデータ追加
4. `collection.query(query_texts=[...])` で検索
5. 本番化: [trychroma.com](https://www.trychroma.com) で Chroma Cloud アカウント作成
$md$,
  'https://docs.trychroma.com/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
