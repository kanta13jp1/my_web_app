---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Oracle (OCI Generative AI) プロバイダー UI 追加依頼

## 背景

Windows版#44 で Oracle AI (OCI Generative AI) を AI大学 19社目として追加しました。
migration 適用済み: `supabase/migrations/20260412010000_seed_oracle_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Oracle を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'oracle': {
  'name': 'Oracle',
  'emoji': '🔴',
  'color': Color(0xFFC74634),  // Oracle brand red
  'description': 'OCI Generative AI',
},
```

### 2. `_fallback` マップに追加

```dart
'oracle': '''
# Oracle OCI Generative AI — エンタープライズ AI プラットフォーム

Oracle は OCI (Oracle Cloud Infrastructure) を通じて Generative AI サービスを提供しています。
Llama / Cohere / Mistral など複数のモデルを 1 つの API で利用でき、Oracle Database 23ai に
AI Vector Search を内蔵しているため、外部ベクトルDBなしで RAG を構築できます。

## 主要モデル
- meta.llama-3.3-70b-instruct (128K, 汎用・高精度)
- meta.llama-3.1-405b-instruct (128K, 最大規模)
- cohere.command-r-plus (128K, RAG特化)
- mistral.mistral-large (128K, 欧州規制対応)
- xai.grok-2 (131K, リアルタイム推論)

## 特徴
- Oracle Database 23ai の AI Vector Search で SQLのみでRAG構築
- OpenAI互換 API (LangChain/LlamaIndex そのまま利用可能)
- Fortune 500 の 98% が Oracle ユーザー — 移行コストゼロ

[Oracle AI](https://www.oracle.com/artificial-intelligence/)
''',
```

### 3. `_quizzes` マップに追加

```dart
'oracle': [
  {
    'question': 'Oracle Database 23ai で SQL を使ってベクトル検索を実行する際に使う関数は？',
    'options': ['VECTOR_DISTANCE()', 'COSINE_SEARCH()', 'AI_SEARCH()', 'EMBED_QUERY()'],
    'answer': 0,
    'explanation': 'VECTOR_DISTANCE() 関数にコサイン類似度などの距離指標を指定し、FETCH FIRST N ROWS ONLY で上位件数を取得します。',
  },
  {
    'question': 'OCI Generative AI で利用できる Cohere のモデルで RAG 特化と評される上位モデルは？',
    'options': ['cohere.command-r-plus', 'cohere.command-r', 'cohere.embed-multilingual-v3.0', 'cohere.rerank-v3'],
    'answer': 0,
    'explanation': 'Cohere Command R+ は RAG・ツール呼び出し・128K コンテキストに最適化されたエンタープライズ向けモデルです。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🔴'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
