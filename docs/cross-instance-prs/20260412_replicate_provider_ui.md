---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Replicate プロバイダー UI 追加依頼

## 背景

Windows版#46 で Replicate を AI大学 24社目として追加しました。
migration 適用済み: `supabase/migrations/20260412015000_seed_replicate_ai_university.sql`

Note: provider キーは `replicate` (ハイフン・アンダースコアなし) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Replicate を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'replicate': {
  'name': 'Replicate',
  'emoji': '🔄',
  'color': Color(0xFF0F0F0F),  // Replicate dark brand
  'description': 'FLUX / SD / Whisper',
},
```

### 2. `_fallback` マップに追加

```dart
'replicate': '''
# Replicate — 画像・動画・音声AIのモデルホスティング

Replicate は数千のオープンソースAIモデルをAPIで提供するプラットフォームです。
画像生成・動画生成・音声認識・音楽生成など、クリエイティブAIに特化しています。

## 主要モデルカテゴリ
- 画像生成: FLUX.1 Pro/dev/schnell / Stable Diffusion 3 / SDXL / ControlNet
- 動画生成: Stable Video Diffusion / AnimateDiff
- 音声: Whisper (多言語音声認識) / MusicGen (音楽生成) / Bark (音声合成)
- テキスト生成: LLaMA / Mixtral

## 特徴
- 秒課金の完全従量制 — アイドル時コストゼロ
- cog ツールで自分のモデルをデプロイして公開共有可能
- Webhook で非同期処理の結果を受信

[Replicate Docs](https://replicate.com/docs)
''',
```

### 3. `_quizzes` マップに追加

```dart
'replicate': [
  {
    'question': 'Replicate で自分のカスタムモデルをデプロイするために使うツールは？',
    'options': ['cog', 'docker-compose', 'kubectl', 'terraform'],
    'answer': 0,
    'explanation': 'cog は Replicate が開発したDockerベースのコンテナ化ツールです。predict.py でモデル推論ロジックを記述し、cog push でReplicate にデプロイできます。',
  },
  {
    'question': 'Replicate の FLUX.1 [schnell] の最大の特徴は？',
    'options': ['4ステップで超高速画像生成 ($0.003/枚)', '最高品質の画像生成', '動画生成対応', 'テキスト理解に特化'],
    'answer': 0,
    'explanation': 'FLUX.1 [schnell] は わずか4ステップで画像を生成できる超高速モデルです。1枚あたり $0.003 と非常に低コストで、プロトタイピングに最適です。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🔄'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
