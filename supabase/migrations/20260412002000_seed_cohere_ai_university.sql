-- Cohere コンテンツシード
-- AI大学: Cohere プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: エンタープライズRAG特化 / Command R+ / API公開済み / 開発者・企業向け差別化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('cohere', 'overview', 'Cohere 概要',
$$Cohere は2019年にトロントで創業されたエンタープライズ向けAI企業です。元 Google Brain の研究者アイダン・ゴメルらが設立し、「企業のデータとAIをつなぐ」ことに特化したプラットフォームを提供しています。

Cohere の最大の特徴は **RAG (Retrieval-Augmented Generation) と企業向け導入への徹底的な最適化**です。一般向けチャットボットではなく、企業の社内文書・ナレッジベースをAIが参照して正確な回答を生成するユースケースに強みを持ちます。

## 主要サービス
- **Cohere Platform** — テキスト生成・埋め込み・分類・RAG の統合 API
- **Command R / R+** — RAG・エージェント動作に特化した商用モデル
- **Embed** — 多言語テキスト埋め込み (1024次元, 100言語以上対応)
- **Rerank** — 検索結果の関連度スコアリング (RAGパイプライン強化)
- **Aya** — オープンウェイトの多言語モデル (130言語対応)

## 強み
- エンタープライズRAGパイプラインに最適化 (Rerank + Embed の組み合わせが業界屈指)
- プライベートデプロイ対応 (AWS / Azure / GCP / オンプレミス)
- GDPR・HIPAA・SOC2 対応 — 金融・医療・法務分野での導入実績
- 100言語以上の多言語サポート (Aya Expanse シリーズ)
- 競合比で埋め込みモデルのコストパフォーマンスが高い$$,
'https://cohere.com/', '2026-04-12', 1),

('cohere', 'models', 'Cohere モデル一覧 (2026)',
$$## Command R シリーズ (RAG・エージェント特化)

| モデル | コンテキスト | 特徴 | 用途 |
| :--- | :--- | :--- | :--- |
| **Command R+** | 128K | 高精度 RAG・マルチステップ推論・Tool Use | 複雑な企業タスク |
| **Command R** | 128K | コスト効率重視の RAG・軽量版 R+ | 高頻度・低コスト用途 |
| **Command R7B** | 128K | 7B パラメータ軽量モデル | オンデバイス・低レイテンシ |
| **Command A** | 256K | 最新フラッグシップ、アクティブパラメータ 35B | 高精度エンタープライズ |

## 埋め込み・Rerank モデル

| モデル | 特徴 | 用途 |
| :--- | :--- | :--- |
| **Embed v3** | 1024次元、100言語以上、float32/binary/int8 対応 | セマンティック検索・RAG |
| **Embed Multilingual** | 多言語横断検索・512次元高速版あり | グローバルアプリ |
| **Rerank v3** | 検索結果の関連度再スコアリング | RAGパイプライン精度向上 |
| **Rerank Multilingual** | 多言語 Rerank | グローバル検索強化 |

## Aya シリーズ (多言語オープンウェイト)

| モデル | 特徴 | 用途 |
| :--- | :--- | :--- |
| **Aya Expanse 8B / 32B** | 130言語対応、Apache 2.0 | 多言語生成・翻訳 |
| **Aya Vision** | 多言語マルチモーダル | 多言語画像理解 |

## RAG パイプラインの黄金組み合わせ
```text
ユーザー質問 → Embed でベクトル化 → 社内DB検索
→ Rerank で上位再スコアリング → Command R+ で回答生成
```
この組み合わせが Cohere の最大の強みです。$$,
'https://docs.cohere.com/docs/models', '2026-04-12', 2),

('cohere', 'api', 'Cohere API 入門',
$$## Cohere API の始め方

```python
import cohere

co = cohere.ClientV2(api_key="your-cohere-api-key")

# テキスト生成
response = co.chat(
    model="command-r-plus",
    messages=[
        {"role": "user", "content": "RAGとは何か説明してください。"}
    ]
)
print(response.message.content[0].text)
```

## RAG パイプライン (Embed + Rerank + Command R)

```python
import cohere
import numpy as np

co = cohere.ClientV2(api_key="your-api-key")

# 1. ドキュメントを埋め込みベクトル化
docs = ["Cohere は企業向けAIプラットフォームです", "RAGは検索拡張生成の略です"]
embed_response = co.embed(
    texts=docs,
    model="embed-v4.0",
    input_type="search_document",
    embedding_types=["float"]
)
doc_vectors = np.array(embed_response.embeddings.float)

# 2. クエリも同様にベクトル化
query = "Cohereのビジネス用途は？"
query_embed = co.embed(
    texts=[query],
    model="embed-v4.0",
    input_type="search_query",
    embedding_types=["float"]
)

# 3. Rerank で精度向上
rerank_response = co.rerank(
    model="rerank-v3.5",
    query=query,
    documents=docs,
    top_n=2
)

# 4. Command R で回答生成 (RAGモード)
chat_response = co.chat(
    model="command-r-plus",
    messages=[{"role": "user", "content": query}],
    documents=[{"data": docs[r.index]} for r in rerank_response.results]
)
print(chat_response.message.content[0].text)
```

## 料金 (2026年4月時点)

| モデル | 入力 (100万トークン) | 出力 (100万トークン) |
| :--- | :--- | :--- |
| **Command R** | $0.15 | $0.60 |
| **Command R+** | $2.50 | $10.00 |
| **Command A** | $2.50 | $10.00 |
| **Embed v4.0** | $0.10 | — |
| **Rerank v3.5** | $2.00 / 1000 クエリ | — |

- **無料トライアル枠あり** (Trial API Key で即開始可能)
- API キーは [Cohere Dashboard](https://dashboard.cohere.com/) で発行
- SDK: `pip install cohere` / npm: `npm install cohere-ai`$$,
'https://docs.cohere.com/docs/the-cohere-platform', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Cohere 追加 (11社目)',
  'Cohere (エンタープライズRAG特化) を AI大学プロバイダーとして追加。overview/models/api の3カテゴリ、日本語コンテンツ、Command R+・Embed・Rerank の組み合わせRAGパイプライン解説を収録。AI大学プロバイダー数 10社→11社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
