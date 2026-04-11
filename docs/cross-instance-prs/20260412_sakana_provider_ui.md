---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Sakana AI プロバイダー UI 追加依頼

## 背景

Windows版#40 で Sakana AI (東京発・進化的モデルマージング) を AI大学 17社目として追加しました。
migration 適用済み: `supabase/migrations/20260412008000_seed_sakana_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Sakana AI を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'sakana': {
  'name': 'Sakana AI',
  'emoji': '🐟',
  'color': Color(0xFF00B4D8),  // Sakana AI brand teal-blue
  'description': '東京発・進化的モデルマージング',
},
```

### 2. `_fallback` マップに追加

```dart
'sakana': '''
# Sakana AI — 東京発・日本語 AI の最前線

Transformer 論文著者の一人 Llion Jones が共同創業した東京の AI 研究スタートアップ。
「進化的モデルマージング」で少ない計算コストで高性能日本語モデルを実現。

## 主要モデル (Hugging Face で無料公開)
- EvoLLM-JP-A-v1-7B: 日本語特化 LLM
- EvoVLM-JP-v1-7B: 日本語マルチモーダル
- Tanuki-8B / Tanuki-8x8B: 実用日本語モデル

## 注目プロジェクト
- AI Scientist: AI が論文を完全自動生成 (世界初)
- Continuous Thought Machines: 新推論アーキテクチャ

全モデルは transformers ライブラリで即利用可能。
[Sakana AI Hub](https://huggingface.co/SakanaAI)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'sakana': [
  {
    'question': 'Sakana AI が開発した独自のモデル作成手法は？',
    'options': ['進化的モデルマージング', 'LoRA ファインチューニング', 'RLHF', '知識蒸留'],
    'answer': 0,
    'explanation': '進化的モデルマージングは、既存のOSSモデルを進化アルゴリズムで最適に組み合わせる手法で、通常のファインチューニングの1/100以下の計算コストで高性能モデルを実現します。',
  },
  {
    'question': 'Sakana AI の共同創業者の一人 Llion Jones は何の論文の著者ですか？',
    'options': ['Transformer (Attention Is All You Need)', 'GPT-1', 'BERT', 'LLaMA'],
    'answer': 0,
    'explanation': 'Llion Jones は「Attention Is All You Need」(2017年) の著者の一人で、現代AI革命の基盤となった Transformer アーキテクチャを提案しました。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🐟'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
