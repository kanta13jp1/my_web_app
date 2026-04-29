-- PS#3 S133: AI大学 360→361社化 — Haystack (deepset / エンタープライズRAG / LLMパイプライン / OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'haystack', 'overview',
  'Haystack (deepset) — エンタープライズRAGフレームワーク・LLMパイプライン・本番グレードNLP (9/9)',
  $$## Haystack とは

**Haystack** はドイツの AI スタートアップ **deepset** が開発したオープンソースの LLM アプリケーションフレームワーク。**エンタープライズグレードの RAG (Retrieval-Augmented Generation)** と LLM パイプライン構築に特化し、本番環境での大規模運用を前提に設計されている。

2020年の初期リリースから継続的に進化し、LangChain と並んで**業界標準の LLM フレームワーク**として定着している。

## LangChain との比較

```
LangChain vs Haystack:

  LangChain:
    ・幅広いユースケースに対応
    ・豊富なインテグレーション
    ・コミュニティが活発
    ・ラピッドプロトタイピング向き

  Haystack:
    ・RAG・NLP に特化
    ・本番グレードの信頼性
    ・エンタープライズサポート
    ・厳格な型システム
    ・テスト・モニタリングが充実

  → どちらを選ぶか:
    実験・プロト → LangChain
    本番・企業導入 → Haystack
```

## Haystack 2.0 のアーキテクチャ

```python
from haystack import Pipeline, Document
from haystack.components.retrievers import InMemoryBM25Retriever
from haystack.components.generators import OpenAIGenerator
from haystack.components.builders import PromptBuilder

# ドキュメントを準備
docs = [
    Document(content="Supabase は PostgreSQL ベースのBaaSです"),
    Document(content="Flutter は Google が開発したUIフレームワーク"),
    Document(content="Edge Functions は Deno ランタイムで動作します"),
]

# RAG パイプラインを構築
pipeline = Pipeline()

# コンポーネントを追加
pipeline.add_component("retriever", InMemoryBM25Retriever(document_store))
pipeline.add_component("prompt_builder", PromptBuilder(
    template="以下のドキュメントを参照して質問に答えてください。\n\nドキュメント: {{documents}}\n\n質問: {{question}}\n\n回答:"
))
pipeline.add_component("llm", OpenAIGenerator(model="gpt-4o"))

# コンポーネントを接続 (パイプライン)
pipeline.connect("retriever", "prompt_builder.documents")
pipeline.connect("prompt_builder", "llm")

# 実行
result = pipeline.run({
    "retriever": {"query": "Supabaseとは何ですか？"},
    "prompt_builder": {"question": "Supabaseとは何ですか？"}
})
print(result["llm"]["replies"][0])
```

## Haystack のコアコンセプト

```
Haystack の構成要素:

  Component (コンポーネント):
    ・入力/出力が型定義された処理単位
    ・Retriever, Generator, Ranker, etc.
    ・カスタムコンポーネントも作れる

  Pipeline (パイプライン):
    ・コンポーネントを DAG (有向非巡回グラフ) で接続
    ・データフローを定義
    ・並列実行もサポート

  Document Store:
    ・InMemory, Elasticsearch, OpenSearch
    ・Weaviate, Qdrant, Pinecone
    ・Chroma, pgvector など多数対応
```

## deepset Cloud

```
deepset のプロダクト:

  Haystack OSS: GitHub で無料公開 (Apache-2.0)
  deepset Cloud: エンタープライズ向けマネージドサービス
    ・パイプラインをビジュアルで構築
    ・本番モニタリング・ログ管理
    ・チームコラボレーション
    ・SLA 保証・セキュリティ
    ・ドイツ GDPR 準拠
```

## 自分株式会社との関連

Haystack の「コンポーネント → パイプライン接続 → 実行」アーキテクチャは、自分株式会社の Supabase Edge Function の設計と同一。各 EF (Edge Function) = Haystack の Component、`schedule-hub` や `ai-hub` = Haystack の Pipeline。さらに自分株式会社の memory-search-hub EF (SECOND_BRAIN #7) が実装予定の「BM25 + ベクトル検索ハイブリッド」は Haystack の Hybrid Retrieval パターンそのもの。
$$,
  'https://github.com/deepset-ai/haystack',
  NOW(),
  361
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
