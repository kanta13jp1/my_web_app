-- PS#3 S134: AI大学 362→363社化 — LlamaIndex (データフレームワーク / RAG / データコネクタ / 35k+ stars)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'llamaindex', 'overview',
  'LlamaIndex — LLM向けデータフレームワーク・RAG・データコネクタ・35k+ stars (9/9)',
  $$## LlamaIndex とは

**LlamaIndex** (旧 GPT Index) は LLM アプリケーションにデータを効率よく接続するための**データフレームワーク**。「LLM × あなたのデータ」を実現する基盤として設計されており、RAG (Retrieval-Augmented Generation) の業界標準ライブラリの一つ。

GitHub **35,000+ stars** を誇り、LangChain と並んで最も広く使われる LLM フレームワーク。

## LlamaIndex の位置づけ

```
LangChain vs LlamaIndex の違い:

  LangChain:
    ・LLM ワークフロー全般
    ・エージェント・チェーン構築
    ・幅広いユースケース
    → "LLM のスイスアーミーナイフ"

  LlamaIndex:
    ・データ接続・インデックス化・検索に特化
    ・「自分のデータに答えさせる」に最適
    ・構造化データ / 非構造化データ両対応
    → "LLM のデータレイヤー"
```

## LlamaIndex のコアコンセプト

```
LlamaIndex の 5 ステップ:

  1. Load (データ読み込み):
    ・PDF, Word, Excel
    ・Web ページ / YouTube
    ・Notion, Slack, GitHub
    ・データベース (SQL / NoSQL)
    ・160+ の DataConnector

  2. Index (インデックス化):
    ・VectorStoreIndex (ベクトル検索)
    ・SummaryIndex (要約ベース)
    ・TreeIndex (階層構造)
    ・KeywordTableIndex (キーワード)

  3. Store (保存):
    ・Chroma, Weaviate, Pinecone
    ・pgvector, Qdrant, Faiss
    ・ローカル JSON / SQLite

  4. Query (クエリ):
    ・自然言語でインデックスに質問
    ・Sub-question Query Engine
    ・RouterQueryEngine (複数インデックス統合)

  5. Evaluate (評価):
    ・Faithfulness (幻覚チェック)
    ・Relevancy (関連性)
    ・Context Precision/Recall
```

## 実際のコード例

```python
from llama_index.core import VectorStoreIndex, SimpleDirectoryReader
from llama_index.llms.openai import OpenAI
from llama_index.embeddings.openai import OpenAIEmbedding

# データを読み込む
documents = SimpleDirectoryReader("./docs").load_data()

# インデックスを構築
index = VectorStoreIndex.from_documents(
    documents,
    embed_model=OpenAIEmbedding(model="text-embedding-3-small")
)

# クエリエンジンを作成
query_engine = index.as_query_engine(
    llm=OpenAI(model="gpt-4o"),
    similarity_top_k=3  # 上位3件のドキュメントを参照
)

# 質問する
response = query_engine.query(
    "このドキュメントの主要な機能は何ですか？"
)
print(response)
print(response.source_nodes)  # 参照したドキュメントも確認できる
```

## LlamaIndex Cloud / LlamaHub

```
LlamaIndex エコシステム:

  LlamaHub:
    ・コミュニティ製 DataConnector ライブラリ
    ・160+ の接続先 (Notion/Slack/GitHub/etc.)
    ・npm install 感覚で追加可能

  LlamaIndex Cloud:
    ・マネージド RAG パイプライン
    ・本番運用・モニタリング
    ・LlamaTrace (可観測性)

  LlamaIndex TS:
    ・TypeScript / JavaScript 版
    ・Next.js / Node.js で使用可
```

## 自分株式会社との関連

自分株式会社の memory-search-hub EF (SECOND_BRAIN #7) で実装予定の「BM25 + ベクトル検索ハイブリッド」は LlamaIndex の HybridSearchRetriever と同一設計。また自分株式会社の claude-mem (SQLite + Gemini 圧縮) は LlamaIndex の VectorStoreIndex + SummaryIndex の組み合わせと同概念。LlamaIndex のコード実装を参照して memory-search-hub の設計を改善できる。
$$,
  'https://github.com/run-llama/llama_index',
  NOW(),
  363
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
