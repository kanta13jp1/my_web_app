---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Voyage AI プロバイダー UI 追加依頼

## 背景

Windows版#48 で Voyage AI を AI大学 27社目として追加しました。
migration 適用済み: `supabase/migrations/20260412018000_seed_voyage_ai_university.sql`

Note: provider キーは `voyage` (そのまま) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Voyage AI を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'voyage': {
  'name': 'Voyage AI',
  'emoji': '⚓',
  'color': Color(0xFF0F4C81),  // Voyage deep blue
  'description': 'Embedding特化 / RAG最適化',
},
```

### 2. `_fallback` マップに追加

```dart
'voyage': '''
# Voyage AI — RAG精度を最大化するEmbedding専門企業

Voyage AI は2023年創業のEmbedding専門企業。MTEB (Massive Text Embedding Benchmark) で
最上位クラスのスコアを達成しており、RAG構築に特化したモデル群を提供しています。

## モデルラインナップ
- voyage-3-large (1024次元, 32K, MTEB上位・最高精度)
- voyage-3 / voyage-3-lite (バランス型 / 軽量高速)
- voyage-code-3 / voyage-finance-2 / voyage-law-2 (ドメイン特化)
- voyage-multilingual-2 (日本語含む多言語対応)
- rerank-2 / rerank-2-lite (2段階RAG用Reranker)

## RAGへの活用
1. voyage-3-large でベクトル検索 (Top-20)
2. rerank-2 で精密再ランキング (Top-3)
これにより「検索漏れ」と「無関係文書の混入」を大幅削減。

[Voyage AI Docs](https://docs.voyageai.com/)
''',
```

### 3. `_quizzes` マップに追加

```dart
'voyage': [
  {
    'question': 'Voyage AI の voyage-3-large が MTEB ベンチマークで評価される指標は？',
    'options': ['Retrieval精度 (nDCG@10) でOpenAI・Cohereを上回る', '画像認識の精度スコア', 'コード生成の正解率', 'テキスト生成の流暢さ'],
    'answer': 0,
    'explanation': 'MTEB (Massive Text Embedding Benchmark) の Retrieval タスクで voyage-3-large は nDCG@10=65.1 を達成し、OpenAI text-embedding-3-large (62.9) やCohere embed-v3 (63.8) を上回ります。',
  },
  {
    'question': 'Voyage AI の Reranker を RAG パイプラインに組み込む目的は？',
    'options': ['ベクトル検索の粗い上位N件を精密に再スコアリングしてRAG精度を向上', 'テキストを圧縮してコストを削減する', 'クエリを自動翻訳する', 'データベースの検索速度を向上させる'],
    'answer': 0,
    'explanation': 'Rerankerは「ベクトル検索で粗く取得した上位N件(例:20件)を、クエリとの意味的関連度で精密に再スコアリングしてTop-K(例:3件)に絞り込む」ためのモデルです。2段階検索で最終的なRAG精度を大幅に向上できます。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'⚓'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
