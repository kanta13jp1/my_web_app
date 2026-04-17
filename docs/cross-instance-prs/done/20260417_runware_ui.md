---
date: 2026-04-17
from: Windowsアプリ版#73
to: VSCode版
status: pending
priority: medium
---

# Runware (Sonic Inference Engine) の UI追加依頼

## 概要

AI大学 77社目として、統一AI推論API企業 **Runware** を追加。

- **Runware**: 画像・動画・音声・3Dを単一APIで扱う統合推論プラットフォーム
- **Sonic Inference Engine®**: 既存比30-40%高速・5-10倍コスト削減
- $50M Series A (2025/12 Dawn Capital・Comcast・Speedinvest)
- 400,000+モデル対応 (2026年末200万+予定)

VSCode版で `lib/pages/gemini_university_v2_page.dart` の以下2箇所に追記してください。

## 追加内容

### 1. `_providerMeta` マップへの追記

```dart
'runware': _ProviderMeta(
  name: 'Runware (Sonic)',
  emoji: '⚡',
  color: const Color(0xFF5E17EB), // Runware brand purple
  officialUrl: 'https://runware.ai/',
),
```

### 2. `_fallback` マップへの追記

```dart
'runware': '''
# Runware (Sonic Inference Engine)

**「One API for all AI」** 推論統合基盤。画像・動画・音声・3Dを単一APIで扱う。

- **Sonic Inference Engine®**: 既存比30-40%高速・5-10倍低コスト
- 400,000+ モデル対応 (FLUX / DALL-E / Kling / Veo / Hailuo / Seedance等)
- $50M Series A (2025/12 Dawn Capital/Comcast)
- 従量課金: 画像 \$0.0006〜 / 動画 \$0.14〜 (サブスク不要)
- 公式: https://runware.ai/
''',
```

### 3. (任意) クイズ追加

```dart
'runware': [
  _QuizItem(
    question: 'Runware の中核技術 Sonic Inference Engine の強みは?',
    options: ['最大コンテキスト長', 'GPU不要CPU推論', '既存比30-40%高速・5-10倍安', '完全無料'],
    correctIndex: 2,
    explanation: '独自のハードウェア最適化により高速かつ低コストな推論を実現。',
  ),
],
```

## 確認事項

- `flutter analyze` で 0 エラーを維持
- 関連 migration: `20260417160000_seed_runware_ai_university.sql`

## 完了後の対応

このファイルを `docs/cross-instance-prs/done/` に移動してマージしてください。
