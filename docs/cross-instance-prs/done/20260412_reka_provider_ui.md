---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Reka AI プロバイダー UI 追加依頼

## 背景

Windows版#44 で Reka AI を AI大学 20社目として追加しました。
migration 適用済み: `supabase/migrations/20260412011000_seed_reka_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Reka を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'reka': {
  'name': 'Reka',
  'emoji': '⚡',
  'color': Color(0xFF6C47FF),  // Reka brand purple
  'description': 'Core / Flash / Edge',
},
```

### 2. `_fallback` マップに追加

```dart
'reka': '''
# Reka AI — マルチモーダル AI (動画理解対応)

Reka は DeepMind・Google Brain 出身のチームが2022年に設立したAIスタートアップです。
テキスト・画像・動画・音声をすべて統一モデルで処理できる点が大きな特徴です。

## モデルラインナップ
- Reka Core (128K, テキスト+画像+動画+音声, 最高精度)
- Reka Flash (128K, テキスト+画像+動画, バランス型)
- Reka Edge (32K, テキスト+画像, 軽量・エッジ向け)

## 特徴
- 動画ファイルを直接入力して内容を分析・要約できる
- OpenAI SDK 互換 API で既存コードをそのまま活用可能
- 日本語を含む多言語対応

[Reka API](https://docs.reka.ai/quick-start)
''',
```

### 3. `_quizzes` マップに追加

```dart
'reka': [
  {
    'question': 'Reka のモデルが他の主要 LLM と大きく異なるマルチモーダル能力とは？',
    'options': ['動画ファイルを直接入力して理解できる', 'リアルタイム音声合成が可能', '3Dモデルの生成ができる', 'オンライン学習(継続訓練)が可能'],
    'answer': 0,
    'explanation': 'Reka Core / Flash は動画ファイルを直接入力でき、映像の内容理解・要約・質問応答が可能です。これは主要 LLM の中でも先進的な機能です。',
  },
  {
    'question': 'Reka API を既存の OpenAI ベースのコードで使うには何を変更すればよいですか？',
    'options': ['base_url を https://api.reka.ai/v1 に変更するだけ', 'SDK を完全に書き直す必要がある', 'プロキシサーバーが必要', 'Python バージョンを変更する必要がある'],
    'answer': 0,
    'explanation': 'Reka は OpenAI 互換エンドポイントを提供しているため、base_url と api_key を変更するだけで既存の OpenAI SDK コードがそのまま動作します。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'⚡'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
