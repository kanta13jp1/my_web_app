-- PS#3 S111: AI大学 316→317社化 — Haystack (エンタープライズRAGフレームワーク/deepset/パイプライン抽象化)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'haystack', 'overview',
  'Haystack — エンタープライズRAGフレームワーク・deepset・パイプライン抽象化 (GitHub 18k+ / 9/9)',
  $$## Haystack とは

**Haystack** は **deepset 社が開発するエンタープライズグレードの RAG・LLM アプリケーションフレームワーク**。GitHub 18,000+ スター。「**LLM パイプラインを宣言的に組み立てる**」思想が核心で、Retriever・Reader・Generator・Ranker などのコンポーネントをパイプラインとして接続し、本番運用に耐える Q&A システムや RAG システムを構築できる。

**Haystack 2.x** (2024年リリース) で完全リアーキテクチャ。`@component` デコレータで任意のPythonクラスをパイプラインコンポーネントに変換できる。LangChain より**エンタープライズ寄り**で、Document Store の抽象化が強力。

## Haystack のアーキテクチャ

```
Haystack 2.x コアコンセプト:

  Pipeline:
    ・コンポーネントを DAG (有向非巡回グラフ) として接続
    ・YAML でパイプライン定義を永続化・再現
    ・非同期実行・並列ブランチ対応

  Component:
    ・@component デコレータで任意クラスをコンポーネント化
    ・入出力型を明示 (型安全なパイプライン接続)
    ・ビルトイン: Retriever / Generator / Ranker / Embedder

  Document Store:
    ・InMemoryDocumentStore (開発・テスト)
    ・ElasticsearchDocumentStore
    ・OpenSearchDocumentStore
    ・QdrantDocumentStore
    ・PineconeDocumentStore
    ・WeaviateDocumentStore

  deepset Cloud:
    ・マネージドHaystack環境
    ・パイプライン管理 UI
    ・評価・モニタリング
```

## 主要コンポーネント

```
Generator (LLM呼び出し):
  ・AnthropicChatGenerator (Claude)
  ・OpenAIChatGenerator
  ・HuggingFaceLocalChatGenerator (ローカルLLM)
  ・OllamaChatGenerator

Embedder (埋め込みベクター生成):
  ・SentenceTransformersDocumentEmbedder
  ・OpenAIDocumentEmbedder
  ・AmazonBedrockDocumentEmbedder

Retriever (文書検索):
  ・InMemoryBM25Retriever (BM25キーワード検索)
  ・InMemoryEmbeddingRetriever (ベクター検索)
  ・ElasticsearchEmbeddingRetriever

Ranker (再ランキング):
  ・TransformersSimilarityRanker
  ・CohereRanker

Converter (フォーマット変換):
  ・PyPDFToDocument
  ・HTMLToDocument
  ・MarkdownToDocument
  ・DOCXToDocument
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **AI大学 Q&A** | ai_university_content → Haystack RAG パイプライン | 316社分のコンテンツへの自然言語 Q&A |
| **競馬ルール検索** | JRA規則PDFをDocumentStoreにインデックス化 | 正確な規則参照で予想精度向上 |
| **エンタープライズ評価** | deepset Cloud でパイプライン品質を可視化 | 本番運用前の RAG 品質保証 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'haystack', 'api',
  'Haystack 実践 — インストール/基本RAGパイプライン/Claude統合/DocumentStore/YAML定義/評価',
  $$## インストール

```bash
pip install haystack-ai
pip install sentence-transformers  # ローカル埋め込み
pip install pypdf                  # PDF読み込み
# ベクターストア (選択)
pip install qdrant-haystack        # Qdrant
pip install elasticsearch-haystack # Elasticsearch
```

## 最速 RAG パイプライン (InMemory)

```python
from haystack import Pipeline, Document
from haystack.document_stores.in_memory import InMemoryDocumentStore
from haystack.components.retrievers.in_memory import InMemoryBM25Retriever
from haystack.components.generators import OpenAIChatGenerator
from haystack.components.builders import ChatPromptBuilder
from haystack.dataclasses import ChatMessage

# Document Store 初期化
document_store = InMemoryDocumentStore()

# ドキュメントを登録
docs = [
    Document(content="vLLM は PagedAttention を使った高速 LLM 推論エンジンです。"),
    Document(content="LlamaIndex は RAG 特化フレームワークで 150+ Data Loaders を持ちます。"),
    Document(content="LangChain は GitHub 94k+ スターの最大の LLM フレームワークです。"),
]
document_store.write_documents(docs)

# パイプライン構築
template = [ChatMessage.from_user("""
コンテキスト:
{% for doc in documents %}
{{ doc.content }}
{% endfor %}

質問: {{ question }}
""")]

pipe = Pipeline()
pipe.add_component("retriever", InMemoryBM25Retriever(document_store=document_store))
pipe.add_component("prompt_builder", ChatPromptBuilder(template=template))
pipe.add_component("llm", OpenAIChatGenerator(model="gpt-4o-mini"))

pipe.connect("retriever.documents", "prompt_builder.documents")
pipe.connect("prompt_builder.prompt", "llm.messages")

# 実行
result = pipe.run({"retriever": {"query": "高速な LLM 推論は？"}, "prompt_builder": {"question": "高速な LLM 推論は？"}})
print(result["llm"]["replies"][0].text)
```

## Claude (Anthropic) 統合

```python
from haystack import Pipeline
from haystack.components.generators.chat import AnthropicChatGenerator
from haystack.components.builders import ChatPromptBuilder
from haystack.dataclasses import ChatMessage

# Claude Generator
llm = AnthropicChatGenerator(
    api_key="YOUR_ANTHROPIC_API_KEY",
    model="claude-haiku-4-5",
    generation_kwargs={"max_tokens": 500},
)

# シンプルなチャットパイプライン
template = [
    ChatMessage.from_system("あなたは日本競馬の専門AIアシスタントです。"),
    ChatMessage.from_user("{{ question }}"),
]

pipe = Pipeline()
pipe.add_component("prompt_builder", ChatPromptBuilder(template=template))
pipe.add_component("llm", llm)
pipe.connect("prompt_builder.prompt", "llm.messages")

result = pipe.run({"prompt_builder": {"question": "天皇賞春の過去10年の傾向を教えてください"}})
print(result["llm"]["replies"][0].text)
```

## PDF → Embedding → ベクター検索 RAG

```python
from haystack import Pipeline
from haystack.document_stores.in_memory import InMemoryDocumentStore
from haystack.components.converters import PyPDFToDocument
from haystack.components.preprocessors import DocumentCleaner, DocumentSplitter
from haystack.components.embedders import SentenceTransformersDocumentEmbedder, SentenceTransformersTextEmbedder
from haystack.components.retrievers.in_memory import InMemoryEmbeddingRetriever
from haystack.components.generators.chat import AnthropicChatGenerator
from haystack.components.builders import ChatPromptBuilder
from haystack.dataclasses import ChatMessage

document_store = InMemoryDocumentStore()

# インデックス作成パイプライン
indexing_pipeline = Pipeline()
indexing_pipeline.add_component("converter", PyPDFToDocument())
indexing_pipeline.add_component("cleaner", DocumentCleaner())
indexing_pipeline.add_component("splitter", DocumentSplitter(split_by="word", split_length=200))
indexing_pipeline.add_component("embedder", SentenceTransformersDocumentEmbedder(
    model="BAAI/bge-small-en-v1.5"
))
indexing_pipeline.add_component("writer", DocumentWriter(document_store=document_store))

indexing_pipeline.connect("converter", "cleaner")
indexing_pipeline.connect("cleaner", "splitter")
indexing_pipeline.connect("splitter", "embedder")
indexing_pipeline.connect("embedder", "writer")

# PDF をインデックス化
indexing_pipeline.run({"converter": {"sources": ["keiba_rules.pdf"]}})

# クエリパイプライン
template = [ChatMessage.from_user("""
{% for doc in documents %}{{ doc.content }}{% endfor %}

質問: {{ question }}
""")]

query_pipeline = Pipeline()
query_pipeline.add_component("text_embedder", SentenceTransformersTextEmbedder(model="BAAI/bge-small-en-v1.5"))
query_pipeline.add_component("retriever", InMemoryEmbeddingRetriever(document_store=document_store, top_k=5))
query_pipeline.add_component("prompt_builder", ChatPromptBuilder(template=template))
query_pipeline.add_component("llm", AnthropicChatGenerator(
    api_key="YOUR_ANTHROPIC_API_KEY",
    model="claude-haiku-4-5",
))

query_pipeline.connect("text_embedder.embedding", "retriever.query_embedding")
query_pipeline.connect("retriever.documents", "prompt_builder.documents")
query_pipeline.connect("prompt_builder.prompt", "llm.messages")

result = query_pipeline.run({
    "text_embedder": {"text": "ゲート入りを拒否した場合のルールは？"},
    "prompt_builder": {"question": "ゲート入りを拒否した場合のルールは？"},
})
print(result["llm"]["replies"][0].text)
```

## YAML でパイプライン定義を保存・再現

```python
# パイプラインを YAML にシリアライズ
with open("rag_pipeline.yaml", "w") as f:
    pipe.dump(f)

# YAML から復元
from haystack import Pipeline
with open("rag_pipeline.yaml", "r") as f:
    loaded_pipe = Pipeline.load(f)
```

## カスタムコンポーネント

```python
from haystack import component
from typing import Optional

@component
class KeibaDataFetcher:
    """競馬データを取得するカスタムコンポーネント"""

    @component.output_types(documents=list)
    def run(self, race_id: str):
        # Supabase から競馬データを取得
        data = fetch_from_supabase(race_id)
        from haystack import Document
        docs = [Document(content=str(row)) for row in data]
        return {"documents": docs}

# パイプラインに追加
pipe.add_component("keiba_fetcher", KeibaDataFetcher())
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 316→317社化: Haystack 追加',
  'PS#3 S111。Haystack (deepset製エンタープライズRAGフレームワーク/Pipeline抽象化/DocumentStore/AnthropicChatGenerator/BM25+Embedding検索/YAML定義/deepset Cloud/GitHub 18k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
