---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Groq プロバイダー UI 追加依頼

## 背景

Windows版#34 で Groq (LPU超高速推論) を AI大学 10社目として追加しました。
migration 適用済み: `supabase/migrations/20260412001000_seed_groq_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Groq を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'groq': {
  'name': 'Groq',
  'emoji': '⚡',
  'color': Color(0xFFF55036),  // Groq brand orange-red
  'description': 'LPU 超高速推論',
},
```

### 2. `_fallback` マップに追加

```dart
'groq': '''
# Groq — LPU 超高速推論

Groq は LPU (Language Processing Unit) という独自チップで
業界最速クラスの AI 推論を提供します。

## 主要モデル
- Llama 4 Scout / Maverick
- Llama 3.3 70B
- Mixtral 8x7B
- Whisper Large v3 (音声認識)

## 特徴
- OpenAI 互換 API — 既存コードをほぼ変更なしで移行可能
- 無料枠あり

[Groq Console](https://console.groq.com/)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'groq': [
  {
    'question': 'Groq が開発した独自 AI チップの名称は？',
    'options': ['LPU', 'TPU', 'GPU', 'NPU'],
    'answer': 0,
    'explanation': 'LPU (Language Processing Unit) は Groq が開発した超高速 AI 推論専用チップです。',
  },
  {
    'question': 'Groq API は何の API と互換性がありますか？',
    'options': ['OpenAI API', 'Anthropic API', 'Gemini API', '独自 API'],
    'answer': 0,
    'explanation': 'Groq API は OpenAI API と互換性があるため、base_url を変更するだけで移行できます。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'⚡'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
