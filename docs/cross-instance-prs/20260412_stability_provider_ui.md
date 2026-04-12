---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Stability AI プロバイダー UI 追加依頼

## 背景

Windows版#36 で Stability AI (Stable Diffusion 開発元) を AI大学 13社目として追加しました。
migration 適用済み: `supabase/migrations/20260412004000_seed_stability_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Stability AI を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'stability': {
  'name': 'Stability AI',
  'emoji': '🎨',
  'color': Color(0xFF6C35DE),  // Stability AI brand purple
  'description': 'Stable Diffusion / 画像生成',
},
```

### 2. `_fallback` マップに追加

```dart
'stability': '''
# Stability AI — 画像・動画生成のパイオニア

Stable Diffusion の開発元。テキストから画像・動画・音楽・3Dモデルを生成する
オープンなAIモデルを提供しています。

## 主要モデル
- Stable Diffusion 3.5 Large/Medium (最高品質画像生成)
- SDXL 1.0 (定番・エコシステム最大)
- Stable Video Diffusion (画像→動画)
- Stable Audio 2.0 (テキスト→音楽/SE)

## 特徴
- OSS: 商用利用可能なオープンウェイトモデル
- ローカル実行対応 (VRAM 8GB+)
- ComfyUI / Automatic1111 エコシステム

[Stability AI Platform](https://platform.stability.ai/)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'stability': [
  {
    'question': 'Stable Diffusion を開発した企業はどこですか？',
    'options': ['Stability AI', 'OpenAI', 'Midjourney', 'Adobe'],
    'answer': 0,
    'explanation': 'Stable Diffusion は Stability AI が開発・公開したオープンソースの画像生成AIです。',
  },
  {
    'question': 'ComfyUI や Automatic1111 でのローカル実行に必要な最小 VRAM は？',
    'options': ['8GB', '4GB', '16GB', '2GB'],
    'answer': 0,
    'explanation': 'SDXL などの高品質モデルを快適に動かすには VRAM 8GB 以上が推奨されています。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🎨'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
