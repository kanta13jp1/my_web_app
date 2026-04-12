---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# AI21 Labs プロバイダー UI 追加依頼

## 背景

Windows版#47 で AI21 Labs を AI大学 26社目として追加しました。
migration 適用済み: `supabase/migrations/20260412017000_seed_ai21_ai_university.sql`

Note: provider キーは `ai21` (そのまま) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に AI21 Labs を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'ai21': {
  'name': 'AI21 Labs',
  'emoji': '🧬',
  'color': Color(0xFF1E40AF),  // AI21 dark blue
  'description': 'Jamba 256K / SSM+Transformer',
},
```

### 2. `_fallback` マップに追加

```dart
'ai21': '''
# AI21 Labs — 256K コンテキストの Jamba モデル

AI21 Labs はイスラエル発の AI 企業。Jamba シリーズは SSM (Mamba) と Transformer を
融合した革新的なアーキテクチャで、256K という業界最長クラスのコンテキストを実現しています。

## モデルラインナップ
- Jamba 1.5 Large (256K, 398B params / active 94B, 最高精度)
- Jamba 1.5 Mini (256K, 52B params / active 12B, 高速・低コスト)

## 特徴
- 256K コンテキスト: 法律文書・財務報告書 100ページ超を一括処理
- MoE (Mixture of Experts): 活性化パラメータ数を抑えつつ高い表現力
- 長文でも従来 Transformer より低コストで効率的

[AI21 Docs](https://docs.ai21.com/)
''',
```

### 3. `_quizzes` マップに追加

```dart
'ai21': [
  {
    'question': 'Jamba のアーキテクチャが革新的な理由は何ですか？',
    'options': ['SSM (Mamba) と Transformer を融合しO(n)の線形計算量で長文処理', '世界最大のパラメータ数', '画像生成に特化した設計', '量子コンピュータを活用'],
    'answer': 0,
    'explanation': 'Jamba は SSM (Mamba/State Space Model) と Transformer を組み合わせたハイブリッドアーキテクチャです。SSMは線形のO(n)計算量で長文を処理でき、256Kコンテキストを効率的にサポートします。',
  },
  {
    'question': 'Jamba 1.5 Large の総パラメータ数と推論時活性化パラメータ数の組み合わせは？',
    'options': ['総 398B / 活性化 94B (MoE構造)', '総 100B / 活性化 100B (Dense)', '総 1T / 活性化 500B', '総 70B / 活性化 70B'],
    'answer': 0,
    'explanation': 'Jamba 1.5 Large は MoE (Mixture of Experts) 構造により、総パラメータ 398B のうち推論時に活性化されるのは約 94B (24%) のみです。これにより大規模な能力を維持しながら推論効率を高めています。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🧬'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
