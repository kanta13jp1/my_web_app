---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Together AI プロバイダー UI 追加依頼

## 背景

Windows版#45 で Together AI を AI大学 22社目として追加しました。
migration 適用済み: `supabase/migrations/20260412013000_seed_together_ai_university.sql`

Note: provider キーは `together_ai` (アンダースコア区切り) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Together AI を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'together_ai': {
  'name': 'Together AI',
  'emoji': '🤝',
  'color': Color(0xFF0066CC),  // Together AI brand blue
  'description': '200+ OSS Models',
},
```

### 2. `_fallback` マップに追加

```dart
'together_ai': '''
# Together AI — オープンソースAIの統合プラットフォーム

Together AI は 200+ のオープンソースAIモデルをひとつのAPIで提供するインフラ企業です。
OpenAI SDK と互換性があり、base_url を変更するだけで既存コードが動作します。

## 代表モデル
- meta-llama/Meta-Llama-3.3-70B-Instruct-Turbo (高精度・高速)
- meta-llama/Meta-Llama-3.1-405B-Instruct-Turbo (最大規模)
- deepseek-ai/DeepSeek-V3 (コーディング特化)
- Qwen/Qwen2.5-72B-Instruct-Turbo (多言語対応)

## 特徴
- Fine-tuning でカスタムモデルを作成し専用エンドポイントとして展開可能
- LLaMA 3.3 70B が最大 180 tokens/秒の高速推論
- GPT-4 比で最大10分の1のコストで同等性能

[Together AI Docs](https://docs.together.ai/)
''',
```

### 3. `_quizzes` マップに追加

```dart
'together_ai': [
  {
    'question': 'Together AI の主な特徴として正しいものは？',
    'options': ['200以上のオープンソースモデルをひとつのAPIで提供', '独自開発のクローズドモデルのみ提供', 'テキスト生成のみ対応', '日本語専用サービス'],
    'answer': 0,
    'explanation': 'Together AI は LLaMA・Mistral・Qwen・DeepSeek など 200+ のオープンソースモデルをひとつの統一APIで提供し、OpenAI SDK と互換性があります。',
  },
  {
    'question': 'Together AI で既存の OpenAI SDK コードをそのまま使うには何を変更すればよい？',
    'options': ['base_url を https://api.together.xyz/v1 に変更するだけ', 'SDK を完全に書き直す', 'Python バージョンを変える', '専用ライブラリが必須'],
    'answer': 0,
    'explanation': 'Together AI は OpenAI 互換エンドポイントを提供しているため、OpenAI クライアントの base_url と api_key を変更するだけで動作します。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🤝'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
