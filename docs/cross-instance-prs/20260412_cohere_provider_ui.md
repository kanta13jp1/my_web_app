---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# Cohere プロバイダー UI 追加依頼

## 背景

Windows版#35 で Cohere (エンタープライズRAG特化) を AI大学 11社目として追加しました。
migration 適用済み: `supabase/migrations/20260412002000_seed_cohere_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Cohere を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'cohere': {
  'name': 'Cohere',
  'emoji': '🏢',
  'color': Color(0xFF39B5F0),  // Cohere brand blue
  'description': 'エンタープライズRAG',
},
```

### 2. `_fallback` マップに追加

```dart
'cohere': '''
# Cohere — エンタープライズ RAG 特化

Cohere は企業向け RAG (検索拡張生成) パイプラインに特化した AI プラットフォームです。
Embed + Rerank + Command R+ の組み合わせが業界最高水準のRAGを実現します。

## 主要モデル
- Command R+ (128K, RAG・エージェント特化)
- Command A (256K, フラッグシップ)
- Embed v4.0 (多言語セマンティック検索)
- Rerank v3.5 (検索精度向上)
- Aya Expanse (130言語対応オープンウェイト)

## 特徴
- エンタープライズ向け GDPR/HIPAA/SOC2 対応
- プライベートデプロイ (AWS / Azure / GCP / オンプレ)
- 無料トライアル枠あり

[Cohere Dashboard](https://dashboard.cohere.com/)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'cohere': [
  {
    'question': 'Cohere の RAG パイプラインで検索結果の精度を向上させるモデルは？',
    'options': ['Rerank', 'Embed', 'Command R', 'Aya'],
    'answer': 0,
    'explanation': 'Rerank は検索結果を関連度でスコアリングし直すことで RAG の精度を大幅に向上させます。',
  },
  {
    'question': 'Cohere Aya Expanse は何言語に対応していますか？',
    'options': ['130言語', '50言語', '30言語', '10言語'],
    'answer': 0,
    'explanation': 'Aya Expanse は 130 言語に対応したオープンウェイトの多言語モデルです。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🏢'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
