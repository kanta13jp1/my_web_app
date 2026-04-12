---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# Runway プロバイダー UI 追加依頼

## 背景

Windows版#50 で Runway を AI大学 31社目として追加しました。
migration 適用済み: `supabase/migrations/20260412022000_seed_runway_ai_university.sql`

provider キー: `runway`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` に以下を追加してください。

### 1. `_providerMeta`

```dart
'runway': {
  'name': 'Runway',
  'emoji': '🎬',
  'color': Color(0xFF0F0F0F),  // Runway brand black
  'description': '動画生成AI / Gen-3 Alpha',
},
```

### 2. `_fallback`

```dart
'runway': '''
# Runway — 動画生成AI最大手 (Gen-3 Alpha)

Runwayはテキスト・画像から高品質な動画を生成するAI企業。
ハリウッド映画のVFXにも採用されています。

## 主要機能
- Text-to-Video: テキストから最大10秒・4K動画を生成
- Image-to-Video: 静止画に動きを付けてアニメーション化
- Gen-3 Alpha Turbo: 高速・低コスト版
- Act-One: 俳優の動きをキャラクターに転写

## 用途
- 広告・CMコンセプト映像の素早い制作
- SNSショート動画 (TikTok/Reels)
- ゲームシネマティック・プロトタイプ

[Runway Docs](https://docs.runwayml.com/)
''',
```

### 3. `_quizzes`

```dart
'runway': [
  {
    'question': 'Runway Gen-3 Alpha の最大動画生成時間は？',
    'options': ['最大10秒 (4K解像度)', '最大60秒 (1080p)', '最大5秒 (720p)', '無制限 (有料プランのみ)'],
    'answer': 0,
    'explanation': 'Runway Gen-3 Alpha は1回のリクエストで最大10秒・最大4K解像度の動画を生成できます。Gen-3 Alpha Turbo はより高速・低コストですが解像度は最大1080pです。複数の短い動画を繋げることで長尺コンテンツも制作可能です。',
  },
  {
    'question': 'RunwayのImage-to-Video機能の主な用途は？',
    'options': ['静止画像に動きを付けてアニメーション動画を生成する', '動画から静止画を抽出してクオリティを向上させる', '複数の画像をスライドショー動画に変換する', '画像のスタイルを変換して別の画像を生成する'],
    'answer': 0,
    'explanation': 'Image-to-Videoは静止画（製品写真・ポートレート・風景など）を入力として、その画像から自然に動きが生まれるアニメーション動画を生成します。製品写真を回転させたり、人物ポートレートに表情の動きを加えたりできます。',
  },
],
```

### 4. `_providerEmojis` に `'🎬'` 追加

## 完了後 `status: done` に変更
