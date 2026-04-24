-- Session PS#3-S42: AI大学 179社化 — Haystack (deepset) 追加
-- deepset (ベルリン/SF 創業 2018) による OSS RAG・LLM アプリケーションフレームワーク。
-- v2 (2024年) でコンポーネントベースパイプライン設計に全面刷新。
-- GitHub 17k+ Stars / pip install haystack-ai / Claude・GPT・Gemini・HuggingFace 対応。
-- DocumentStore: Weaviate / Pinecone / Elasticsearch / pgvector / Chroma / Qdrant 対応。
-- deepset Cloud: マネージドプラットフォーム + アノテーション + 実験管理。
-- Step 0: 8/9 (17k+ Stars / v2フル刷新 / 広大なintegrations / deepset Cloud / Claude対応)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'haystack',
  'overview',
  'Haystack (deepset) — OSS RAG・LLM アプリフレームワーク (17k+ Stars / v2 コンポーネント設計)',
  $md$
# Haystack — Build LLM Applications with Composable Components

**deepset** (ベルリン + サンフランシスコ) が開発する OSS の
RAG・LLM アプリケーションフレームワーク。

2024 年にリリースした **v2** でコンポーネントベースの設計に全面刷新。
「Pipelines = Components を接続した有向グラフ」という思想で、
シンプルな RAG から複雑なエージェント型ワークフローまで構築できる。

GitHub Stars **17,000+** / `pip install haystack-ai`

## v2 コアコンセプト

| 概念 | 説明 |
| :--- | :--- |
| **Component** | 単一の処理単位 (Embedder / Retriever / Generator / Router など) |
| **Pipeline** | Component を接続した有向グラフ (DAG) |
| **DocumentStore** | ドキュメントの保存・検索バックエンド |

## 対応 LLM

| プロバイダー | Component |
| :--- | :--- |
| **Anthropic** | `AnthropicChatGenerator` |
| **OpenAI** | `OpenAIChatGenerator` |
| **Google Gemini** | `GoogleAIGeminiChatGenerator` |
| **HuggingFace** | `HuggingFaceTGIChatGenerator` |
| **Ollama** | `OllamaChatGenerator` (ローカル) |
| **Cohere** | `CohereChatGenerator` |

## 対応 DocumentStore

Weaviate / Pinecone / Elasticsearch / PostgreSQL (pgvector) /
Chroma / Qdrant / OpenSearch / MongoDB Atlas / Redis

## deepset Cloud (エンタープライズ)

- マネージドパイプライン実行環境
- アノテーションツール (人間フィードバックで精度改善)
- 実験管理 (パイプライン比較・バージョン管理)
- API エンドポイント自動生成
$md$,
  'https://haystack.deepset.ai/',
  '2026-04-24',
  1
),

(
  'haystack',
  'models',
  'Haystack v2 コンポーネント一覧 & パイプライン設計パターン (2026)',
  $md$
## 主要コンポーネント

### Embedders (埋め込み生成)

| Component | 説明 |
| :--- | :--- |
| `SentenceTransformersTextEmbedder` | HuggingFace モデルでローカル埋め込み |
| `OpenAITextEmbedder` | OpenAI text-embedding-3-small/large |
| `CohereTextEmbedder` | Cohere embed-v3 |

### Retrievers (検索)

| Component | 説明 |
| :--- | :--- |
| `InMemoryEmbeddingRetriever` | ローカル開発用インメモリ検索 |
| `WeaviateEmbeddingRetriever` | Weaviate ベクター検索 |
| `PineconeEmbeddingRetriever` | Pinecone 検索 |
| `FilterRetriever` | メタデータフィルター検索 |

### Generators (回答生成)

| Component | 説明 |
| :--- | :--- |
| `AnthropicChatGenerator` | Claude モデルで回答生成 |
| `OpenAIChatGenerator` | GPT モデルで回答生成 |
| `HuggingFaceLocalGenerator` | ローカル OSS モデル |

### Routers & Converters

| Component | 説明 |
| :--- | :--- |
| `MetadataRouter` | メタデータ条件でルーティング |
| `LLMMetadataExtractor` | LLM でメタデータ抽出 |
| `PDFToDocument` | PDF → Document 変換 |
| `HTMLToDocument` | HTML → Document 変換 |

## 代表的なパイプラインパターン

| パターン | 構成 |
| :--- | :--- |
| **Basic RAG** | Embedder → Retriever → PromptBuilder → Generator |
| **Hybrid Search** | BM25Retriever + EmbeddingRetriever → JoinDocuments → Generator |
| **Conversational RAG** | ChatHistoryConnector + RAG Pipeline |
| **Agent** | Tool 呼び出し対応の Generator + ToolInvoker ループ |

## 評価コンポーネント

- `ContextRelevanceEvaluator` — 検索結果の関連性
- `FaithfulnessEvaluator` — 回答の忠実性 (RAG 精度)
- `SASEvaluator` — セマンティック回答スコア
$md$,
  'https://docs.haystack.deepset.ai/docs/components',
  '2026-04-24',
  2
),

(
  'haystack',
  'api',
  'Haystack API 入門 — RAG パイプライン構築 (v2)',
  $md$
## Haystack の始め方

### インストール

```bash
pip install haystack-ai
# DocumentStore 追加 (例: Weaviate)
pip install weaviate-haystack
```

### シンプルな RAG パイプライン (Claude 使用)

```python
from haystack import Pipeline, Document
from haystack.document_stores.in_memory import InMemoryDocumentStore
from haystack.components.retrievers.in_memory import InMemoryEmbeddingRetriever
from haystack.components.builders import PromptBuilder
from haystack.components.embedders import SentenceTransformersTextEmbedder, SentenceTransformersDocumentEmbedder
from haystack.components.generators.chat import AnthropicChatGenerator

# ドキュメントストア作成
doc_store = InMemoryDocumentStore()

# ドキュメントをインデックス化
doc_embedder = SentenceTransformersDocumentEmbedder(model="intfloat/multilingual-e5-large")
doc_embedder.warm_up()

docs = [
    Document(content="AutoGen は Microsoft Research が開発するマルチエージェント OSS フレームワークです。"),
    Document(content="CrewAI は Fortune 500 の 60% が採用するエージェントオーケストレーションツールです。"),
    Document(content="Agno は旧 phidata で、Memory と Knowledge を統合した Python-native エージェントフレームワークです。"),
]
docs_with_embeddings = doc_embedder.run(docs)["documents"]
doc_store.write_documents(docs_with_embeddings)

# RAG パイプライン構築
rag_pipeline = Pipeline()
rag_pipeline.add_component("embedder", SentenceTransformersTextEmbedder(model="intfloat/multilingual-e5-large"))
rag_pipeline.add_component("retriever", InMemoryEmbeddingRetriever(document_store=doc_store))
rag_pipeline.add_component("prompt_builder", PromptBuilder(template="""
以下のコンテキストを参照して質問に回答してください。

コンテキスト:
{% for doc in documents %}
{{ doc.content }}
{% endfor %}

質問: {{ question }}
"""))
rag_pipeline.add_component("llm", AnthropicChatGenerator(model="claude-opus-4-7"))

# コンポーネントを接続
rag_pipeline.connect("embedder.embedding", "retriever.query_embedding")
rag_pipeline.connect("retriever.documents", "prompt_builder.documents")
rag_pipeline.connect("prompt_builder.prompt", "llm.messages")

# 実行
result = rag_pipeline.run({
    "embedder": {"text": "マルチエージェントのフレームワークは？"},
    "prompt_builder": {"question": "マルチエージェントのフレームワークは？"},
})
print(result["llm"]["replies"][0].content)
```

### PDF からの RAG (本番ユースケース)

```python
from haystack import Pipeline
from haystack.components.converters import PyPDFToDocument
from haystack.components.preprocessors import DocumentCleaner, DocumentSplitter
from haystack.components.embedders import SentenceTransformersDocumentEmbedder
from haystack.components.writers import DocumentWriter
from haystack_integrations.document_stores.weaviate import WeaviateDocumentStore

# インデックスパイプライン
indexing = Pipeline()
indexing.add_component("converter", PyPDFToDocument())
indexing.add_component("cleaner", DocumentCleaner())
indexing.add_component("splitter", DocumentSplitter(split_by="sentence", split_length=5))
indexing.add_component("embedder", SentenceTransformersDocumentEmbedder())
indexing.add_component("writer", DocumentWriter(document_store=WeaviateDocumentStore()))

indexing.connect("converter", "cleaner")
indexing.connect("cleaner", "splitter")
indexing.connect("splitter", "embedder")
indexing.connect("embedder", "writer")

indexing.run({"converter": {"sources": ["ai_university_catalog.pdf"]}})
```

### パイプラインの YAML 保存 & 読み込み

```python
# 保存
rag_pipeline.dump(open("rag_pipeline.yaml", "w"))

# 読み込み (再利用・デプロイ)
from haystack import Pipeline
loaded = Pipeline.load(open("rag_pipeline.yaml"))
```

## クイックスタート

1. `pip install haystack-ai` でインストール
2. `InMemoryDocumentStore` で即座にローカル RAG 構築
3. `AnthropicChatGenerator(model="claude-opus-4-7")` で Claude 統合
4. `Pipeline.connect()` でコンポーネントを DAG 接続
5. 本番: Weaviate / Pinecone Store + deepset Cloud でスケール
$md$,
  'https://docs.haystack.deepset.ai/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
