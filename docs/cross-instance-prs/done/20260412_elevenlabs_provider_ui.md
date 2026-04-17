---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# ElevenLabs プロバイダー UI 追加依頼

## 背景

Windows版#48 で ElevenLabs を AI大学 28社目として追加しました。
migration 適用済み: `supabase/migrations/20260412019000_seed_elevenlabs_ai_university.sql`

Note: provider キーは `elevenlabs` (そのまま) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に ElevenLabs を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'elevenlabs': {
  'name': 'ElevenLabs',
  'emoji': '🎙️',
  'color': Color(0xFF1A1A1A),  // ElevenLabs brand black
  'description': 'テキスト読み上げ / 音声クローン',
},
```

### 2. `_fallback` マップに追加

```dart
'elevenlabs': '''
# ElevenLabs — 音声AI最大手のTTS・音声クローンサービス

ElevenLabs は2022年創業の音声AI企業。テキスト読み上げ・音声クローン・
リアルタイム音声変換を提供し、100万人以上の開発者が利用しています。

## モデルラインナップ
- Eleven Multilingual v2 (32言語・最高品質)
- Eleven Turbo v2.5 (低レイテンシ <250ms / AIエージェント向け)
- Eleven Flash v2.5 (超高速 <75ms / バッチ処理向け)
- Professional Voice Clone (PVC) / Instant Voice Clone (IVC)

## 主要ユースケース
- YouTubeナレーション・ポッドキャスト・有声本
- AI音声会話Bot (Claude + ElevenLabs)
- ゲームキャラクターボイス生成
- eラーニングコンテンツ読み上げ

[ElevenLabs Docs](https://elevenlabs.io/docs)
''',
```

### 3. `_quizzes` マップに追加

```dart
'elevenlabs': [
  {
    'question': 'ElevenLabs の Eleven Turbo v2.5 の主な特徴は？',
    'options': ['低レイテンシ (<250ms) でリアルタイムAI音声エージェントに最適', '最高音質の有声本生成専用モデル', '音声認識 (STT) に特化したモデル', '画像から音声を生成するマルチモーダルモデル'],
    'answer': 0,
    'explanation': 'Eleven Turbo v2.5 は 250ms 未満の低レイテンシを実現し、AIチャットBotやカスタマーサポートなどリアルタイム音声応答が必要なエージェント向けに最適化されています。高品質重視なら Multilingual v2、コスト・速度重視なら Flash v2.5 を選択します。',
  },
  {
    'question': 'ElevenLabs の Instant Voice Clone (IVC) の特徴は？',
    'options': ['1分未満の音声サンプルから個人の声を再現するクローン機能', '100時間以上の録音が必要なスタジオ品質クローン', 'テキスト指示だけで声を生成するAI機能', '音声ファイルを圧縮・最適化する機能'],
    'answer': 0,
    'explanation': 'Instant Voice Clone (IVC) は短い音声サンプル (1分程度) から個人の声の特徴を学習してクローンを作成します。より高品質な Professional Voice Clone (PVC) は30分以上の録音が必要ですが、商用・エンタープライズ向けに最高精度を提供します。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🎙️'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
