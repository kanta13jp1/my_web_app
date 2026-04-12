---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# OpenRouter プロバイダー UI 追加依頼

## 背景

Windows版#49 で OpenRouter を AI大学 29社目として追加しました。
migration 適用済み: `supabase/migrations/20260412020000_seed_openrouter_ai_university.sql`

Note: provider キーは `openrouter` です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に追加してください。

### 1. `_providerMeta` マップに追加

```dart
'openrouter': {
  'name': 'OpenRouter',
  'emoji': '🔀',
  'color': Color(0xFF6240C8),  // OpenRouter brand purple
  'description': '200+モデルAPIルーター / フォールバック',
},
```

### 2. `_fallback` マップに追加

```dart
'openrouter': '''
# OpenRouter — 200+モデルをひとつのAPIで

OpenRouter は単一のOpenAI互換エンドポイント (https://openrouter.ai/api/v1) で
Claude・GPT・Gemini・LLaMA・DeepSeekなど200以上のLLMにアクセスできるAPIルーターです。

## 主な機能
- OpenAI SDK互換 (base_url変更のみ)
- 自動フォールバック: メインモデル失敗時に自動で代替へ
- コスト比較: 同一プロンプトを複数モデルで実行して比較
- 無料モデル: LLaMA 3.2 3B / Mistral 7Bなど無料枠あり

## 活用場面
- ベンダーロックイン回避 (コード変更なしでモデル切り替え)
- 本番でのA/Bテスト (Claude vs GPT vs Gemini)
- コスト最適化 (タスクに最安モデルを自動選択)

[OpenRouter Docs](https://openrouter.ai/docs)
''',
```

### 3. `_quizzes` マップに追加

```dart
'openrouter': [
  {
    'question': 'OpenRouterが提供するエンドポイントは既存のどのSDKと互換性がある？',
    'options': ['OpenAI SDK (base_urlをhttps://openrouter.ai/api/v1に変更するだけ)', 'LangChain専用のカスタムSDKのみ', 'Anthropic SDKのみ', '独自のOpenRouter SDKのみ'],
    'answer': 0,
    'explanation': 'OpenRouterのエンドポイントはOpenAI APIと完全互換です。既存のOpenAI SDKで「base_url="https://openrouter.ai/api/v1"」と「api_key=OPENROUTER_KEY」を指定するだけで、Claude・Gemini・LLaMAなど200+モデルに切り替えられます。',
  },
  {
    'question': 'OpenRouterのフォールバック機能の主な用途は？',
    'options': ['メインモデルが失敗・過負荷時に自動で代替モデルへ切り替えてサービス継続', 'モデルの回答を複数まとめて平均を取る', 'モデルを並列実行して一番速い回答を返す', '無料モデルのみを優先使用する'],
    'answer': 0,
    'explanation': 'OpenRouterのフォールバック機能は、APIエラー・レート制限・タイムアウト時に自動的に次の候補モデルへ切り替えます。例: Claude失敗→GPT-4o→Gemini Flashの順で試行。本番サービスの可用性を高めるために使われます。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🔀'` を追加。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
