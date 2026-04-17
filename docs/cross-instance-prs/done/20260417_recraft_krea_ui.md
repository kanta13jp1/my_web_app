---
date: 2026-04-17
from: Windowsアプリ版#70
to: VSCode版
status: pending
priority: medium
---

# Recraft AI + Krea AI の UI追加依頼

## 概要

AI大学 71-72社目として Recraft AI と Krea AI のmigrationを追加済み。
VSCode版で `lib/pages/gemini_university_v2_page.dart` の以下2箇所に追記してください。

## 追加内容

### 1. `_providerMeta` マップへの追記

```dart
'recraft': _ProviderMeta(
  name: 'Recraft',
  emoji: '🎨',
  color: const Color(0xFFE74C3C), // デザイン特化 → レッドオレンジ
  officialUrl: 'https://www.recraft.ai/',
),
'krea': _ProviderMeta(
  name: 'Krea',
  emoji: '⚡',
  color: const Color(0xFF7B68EE), // リアルタイム・集約 → パープル
  officialUrl: 'https://www.krea.ai/',
),
```

### 2. `_fallback` マップへの追記 (未接続時のフォールバック)

```dart
'recraft': '''
# Recraft AI

世界唯一レベルの SVG ベクター生成に特化。2026年2月の V4 で Midjourney・DALL·E を超えた画像生成ベンチで話題。

- **V4 / V4 Pro**: ラスター画像 (1MP / 4MP)
- **V4 Vector / Vector Pro**: 編集可能 SVG
- 公式: https://www.recraft.ai/
''',
'krea': '''
# Krea AI

リアルタイム画像・動画生成 (50ms 以下) + 40+ モデル集約プラットフォーム。

- **Krea Realtime 14B**: オープンソース動画モデル
- **Node Editor**: 生成チェーンを GUI で構築
- 公式: https://www.krea.ai/
''',
```

### 3. (任意) クイズ追加 — `_quizzes` マップ

```dart
'recraft': [
  _QuizItem(
    question: 'Recraft V4 が他の画像生成モデルと決定的に差別化している要素は?',
    options: ['高速推論', '編集可能なSVGベクター生成', 'ゼロショット翻訳', '3D メッシュ生成'],
    correctIndex: 1,
    explanation: 'V4 は唯一のプロダクショングレード SVG ベクター生成モデル。',
  ),
],
'krea': [
  _QuizItem(
    question: 'Krea AI のリアルタイム画像生成の応答速度は?',
    options: ['約1秒', '約500ms', '約50ms以下', '約10秒'],
    correctIndex: 2,
    explanation: '50ms 以下で描画や入力に即応するのが最大の差別化ポイント。',
  ),
],
```

## 確認事項

- `flutter analyze` で 0 エラーを維持すること
- DB駆動のため `_providerMeta` 追加だけでもタブは生成される (emoji/色のみのカスタマイズ)
- 関連 migration: `supabase/migrations/20260417096000_seed_recraft_ai_university.sql` + `20260417097000_seed_krea_ai_university.sql`

## 完了後の対応

このファイルを `docs/cross-instance-prs/done/` に移動してマージしてください。
