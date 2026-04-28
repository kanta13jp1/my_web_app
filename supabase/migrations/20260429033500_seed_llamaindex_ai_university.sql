-- PS#3 S110: AI大学 314→315社化 — LlamaIndex (RAGフレームワーク/データインデックス/LLMオーケストレーション)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llamaindex', 'overview',
  'LlamaIndex — RAG特化フレームワーク・データ接続・マルチモーダルインデックス (GitHub 37k+ / 9/9)',
  $$## LlamaIndex とは

**LlamaIndex** は **LLM アプリケーションに外部データを接続するための RAG (Retrieval-Augmented Generation) フレームワーク**。GitHub 37,000+ スター。「LLM に独自データを賢く食わせる」ことに特化し、**データの取り込み・インデックス化・クエリ・合成** までを一貫して提供する。

PDF・Web サイト・データベース・Notion・Slack などあらゆるデータソースを LLM に接続できる。**LangChain が汎用 AI ワークフローなのに対し、LlamaIndex は RAG 特化** で、精度と柔軟性が高い。

## LlamaIndex のアーキテクチャ

```
LlamaIndex の 5 ステップ:

  1. Load (データ取り込み):
     ・150+ Data Loaders (PDF / Web / DB / Notion / Slack 等)
     ・Document 型に統一

  2. Index (インデックス化):
     ・VectorStoreIndex (ベクター検索)
     ・SummaryIndex (サマリー検索)
     ・KnowledgeGraphIndex (知識グラフ)
     ・SQLStructStoreIndex (SQL クエリ)

  3. Store (永続化):
     ・Chroma / Pinecone / Weaviate / Qdrant / pgvector
     ・ローカル JSON / Redis

  4. Query (クエリエンジン):
     ・RetrieverQueryEngine (標準 RAG)
     ・RouterQueryEngine (複数インデックスのルーティング)
     ・SubQuestionQueryEngine (複合質問分解)
     ・HyDE (Hypothetical Document Embeddings)

  5. Evaluate (評価):
     ・Faithfulness / Relevancy / Context Precision
     ・RAGAs 互換評価指標
```

## 主要コンポーネント

```
LLM サポート:
  ・Anthropic Claude (claude-sonnet-4-6 / claude-haiku-4-5)
  ・OpenAI GPT-4o
  ・Google Gemini
  ・Ollama (ローカル)
  ・HuggingFace

埋め込みモデル:
  ・OpenAI text-embedding-3-large
  ・HuggingFace BAAI/bge-large-en-v1.5
  ・Ollama nomic-embed-text (ローカル)

ベクターストア:
  ・Chroma (ローカル OSS)
  ・pgvector (Supabase!)
  ・Pinecone / Weaviate / Qdrant
  ・FAISS (ローカル高速)

Data Loaders (LlamaHub):
  ・PyMuPDF (PDF)
  ・BeautifulSoup (Web)
  ・SQLDatabase
  ・NotionPageReader
  ・SlackReader
  ・YouTubeTranscriptReader
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **競馬知識 RAG** | JRA 競馬規則・血統書PDF を LlamaIndex で検索可能に | 正確な知識ベース回答 |
| **Supabase pgvector** | ai_university_content テーブルをベクター検索 | AI大学コンテンツの意味検索 |
| **マルチドキュメント Q&A** | 複数レースデータを同時クエリで総合判断 | 複合要素の的中率向上 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llamaindex', 'api',
  'LlamaIndex 実践 — インストール/基本RAG/PDF読み込み/pgvector/Supabase統合/カスタムRetriever/評価',
  $$## インストール

```bash
pip install llama-index
pip install llama-index-llms-anthropic      # Claude
pip install llama-index-embeddings-huggingface # HuggingFace 埋め込み
pip install llama-index-vector-stores-chroma   # Chroma ベクターストア
pip install llama-index-readers-file           # PDF 等のリーダー
```

## 最速RAG (5行)

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader

# ドキュメント読み込み
documents = SimpleDirectoryReader("./data/").load_data()

# インデックス作成
index = VectorStoreIndex.from_documents(documents)

# クエリエンジン作成
query_engine = index.as_query_engine()

# 質問する
response = query_engine.query("競馬の三連複の買い方を教えて")
print(response)
```

## Claude + ローカル埋め込み (コスト最適化)

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader, Settings
from llama_index.llms.anthropic import Anthropic
from llama_index.embeddings.huggingface import HuggingFaceEmbedding

# LLM は Claude (推論品質重視)
# Embeddings はローカル (OpenAI API コスト削減)
Settings.llm = Anthropic(
    model="claude-haiku-4-5",
    api_key="YOUR_ANTHROPIC_API_KEY",
    max_tokens=1000,
)
Settings.embed_model = HuggingFaceEmbedding(
    model_name="BAAI/bge-small-en-v1.5",  # 無料・高速
)

# PDF からインデックス作成
from llama_index.readers.file import PyMuPDFReader

loader = PyMuPDFReader()
documents = loader.load(file_path="./data/keiba_rules.pdf")

index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine(similarity_top_k=3)

response = query_engine.query("ゲート入りを拒否した場合のルールは？")
print(f"Answer: {response}")
print(f"\nSources:")
for node in response.source_nodes:
    print(f"  - Page {node.metadata.get('page_label')}: {node.text[:100]}...")
```

## Supabase pgvector との統合

```python
from llama_index.core import VectorStoreIndex, StorageContext
from llama_index.vector_stores.postgres import PGVectorStore
from sqlalchemy import make_url

# Supabase PostgreSQL + pgvector への接続
connection_string = "postgresql://postgres:[PASSWORD]@[HOST]:5432/postgres"
url = make_url(connection_string)

vector_store = PGVectorStore.from_params(
    database="postgres",
    host=url.host,
    password=url.password,
    port=url.port,
    user=url.username,
    table_name="ai_university_vectors",
    embed_dim=1536,  # OpenAI ada-002 の次元数
)

# ストレージコンテキスト
storage_context = StorageContext.from_defaults(vector_store=vector_store)

# ai_university_content を pgvector にインデックス化
from llama_index.core import Document

documents = [
    Document(
        text="vLLM は PagedAttention を使った高速LLM推論エンジンです。",
        metadata={"provider": "vllm", "category": "overview"},
    ),
    Document(
        text="Ollama は1コマンドでローカルLLMを起動できます。",
        metadata={"provider": "ollama", "category": "overview"},
    ),
]

index = VectorStoreIndex.from_documents(
    documents,
    storage_context=storage_context,
)

# クエリ
query_engine = index.as_query_engine(similarity_top_k=5)
response = query_engine.query("高速な LLM 推論エンジンを教えて")
print(response)
```

## Web サイトからのインデックス作成

```python
from llama_index.core import VectorStoreIndex
from llama_index.readers.web import BeautifulSoupWebReader

# Web ページを読み込み
loader = BeautifulSoupWebReader()
documents = loader.load_data(urls=[
    "https://jra.jp/keiba/",
    "https://jra.jp/data/",
])

index = VectorStoreIndex.from_documents(documents)
query_engine = index.as_query_engine()

response = query_engine.query("今週末のG1レースはどこで開催されますか？")
print(response)
```

## SubQuestion Query Engine (複合質問)

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader
from llama_index.core.query_engine import SubQuestionQueryEngine
from llama_index.core.tools import QueryEngineTool, ToolMetadata

# 複数のインデックスを作成
race_docs = SimpleDirectoryReader("./data/races/").load_data()
horse_docs = SimpleDirectoryReader("./data/horses/").load_data()

race_index = VectorStoreIndex.from_documents(race_docs)
horse_index = VectorStoreIndex.from_documents(horse_docs)

# ツールとして登録
query_engine_tools = [
    QueryEngineTool(
        query_engine=race_index.as_query_engine(),
        metadata=ToolMetadata(
            name="race_data",
            description="レース情報・コース・距離・開催日程のデータ",
        ),
    ),
    QueryEngineTool(
        query_engine=horse_index.as_query_engine(),
        metadata=ToolMetadata(
            name="horse_data",
            description="馬の血統・戦績・騎手・調教師のデータ",
        ),
    ),
]

# 複合質問を自動分解して複数インデックスに投げる
query_engine = SubQuestionQueryEngine.from_defaults(
    query_engine_tools=query_engine_tools,
)

response = query_engine.query(
    "今週の天皇賞に出走する馬の中で、東京コースの相性が最も良い馬はどれ？"
)
print(response)
```

## RAG 評価 (Faithfulness / Relevancy)

```python
from llama_index.core.evaluation import FaithfulnessEvaluator, RelevancyEvaluator
from llama_index.llms.anthropic import Anthropic

llm = Anthropic(model="claude-sonnet-4-6")

# 忠実性評価 (回答がソースに基づいているか)
faithfulness_eval = FaithfulnessEvaluator(llm=llm)
# 関連性評価 (回答が質問に関連しているか)
relevancy_eval = RelevancyEvaluator(llm=llm)

# クエリを実行
query_engine = index.as_query_engine()
query = "LLM の推論高速化手法を教えて"
response = query_engine.query(query)

# 評価
faith_result = faithfulness_eval.evaluate_response(response=response)
rel_result = relevancy_eval.evaluate_response(query=query, response=response)

print(f"Faithfulness: {faith_result.passing} (score: {faith_result.score:.2f})")
print(f"Relevancy: {rel_result.passing} (score: {rel_result.score:.2f})")
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 314→315社化: LlamaIndex 追加',
  'PS#3 S110。LlamaIndex (RAG特化フレームワーク/150+ Data Loaders/VectorStoreIndex/Supabase pgvector統合/SubQuestion分解/Claude+HuggingFace埋め込み/RAG評価/GitHub 37k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
