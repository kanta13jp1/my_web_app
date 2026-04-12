---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# Fireworks AI プロバイダー UI 追加依頼

## 背景

Windows版#46 で Fireworks AI を AI大学 23社目として追加しました。
migration 適用済み: `supabase/migrations/20260412014000_seed_fireworks_ai_university.sql`

Note: provider キーは `fireworks_ai` (アンダースコア区切り) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Fireworks AI を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'fireworks_ai': {
  'name': 'Fireworks AI',
  'emoji': '🎆',
  'color': Color(0xFFFF6B00),  // Fireworks orange
  'description': '高速推論 / FLUX画像生成',
},
```

### 2. `_fallback` マップに追加

```dart
'fireworks_ai': '''
# Fireworks AI — 最速オープンソースAI推論

Fireworks AI はオープンソースモデルの高速推論に特化したAIインフラ企業です。
LLaMA 3.3 70B で業界最高水準の 150+ tokens/秒を実現します。

## 対応カテゴリ
- テキスト生成: LLaMA / Mixtral / Qwen / DeepSeek (Function Calling対応)
- 画像生成: FLUX.1 [dev/schnell] / Stable Diffusion XL
- 音声認識: Whisper v3 / Whisper v3 Turbo

## 特徴
- OpenAI 互換 API (base_url 変更のみで既存コード動作)
- 同一プロンプトのキャッシュで最大 80% コスト削減
- サーバーレス課金 + 専有エンドポイントの2モード

[Fireworks AI Docs](https://docs.fireworks.ai/)
''',
```

### 3. `_quizzes` マップに追加

```dart
'fireworks_ai': [
  {
    'question': 'Fireworks AI が他のオープンソースモデルAPIと比べて特に強みとする点は？',
    'options': ['業界最高水準の推論速度 (150+ tokens/秒)', '最多モデル数 (1000本以上)', '最安値の料金設定', '独自開発の専用LLM'],
    'answer': 0,
    'explanation': 'Fireworks AI は推論速度の最適化に特化しており、LLaMA 3.3 70B で 150+ tokens/秒と業界トップクラスのスループットを実現しています。',
  },
  {
    'question': 'Fireworks AI の画像生成で超高速・低コストとして提供されているFLUXモデルは？',
    'options': ['FLUX.1 [schnell]', 'FLUX.1 [dev]', 'FLUX Pro', 'FLUX Ultra'],
    'answer': 0,
    'explanation': 'FLUX.1 [schnell] は4ステップで画像生成できる超高速モデルで、1枚あたり $0.004 と低コストです。高品質が必要な場合は FLUX.1 [dev] を使います。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🎆'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
