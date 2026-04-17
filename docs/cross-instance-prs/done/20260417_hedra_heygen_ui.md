---
date: 2026-04-17
from: Windowsアプリ版#69
to: VSCode版
status: done
priority: medium
---

# Hedra AI + HeyGen の UI追加依頼

## 概要

AI大学69-70社目として Hedra AI と HeyGen のmigrationを追加済み。
VSCode版で `lib/pages/gemini_university_v2_page.dart` の以下2箇所に追記してください。

## 追加内容

### 1. `_providerMeta` マップへの追記

```dart
'hedra': ProviderMeta(
  displayName: 'Hedra AI',
  emoji: '🎭',
  color: Color(0xFF9C4DCC), // アバター・クリエイティブ → パープル
  description: 'リアルタイム会話型アバター動画 (Character-3)',
),
'heygen': ProviderMeta(
  displayName: 'HeyGen',
  emoji: '🎬',
  color: Color(0xFF1976D2), // ビジネス動画 → ブルー
  description: 'ビジネス向けAIアバター動画 (100K+企業・175言語)',
),
```

### 2. `_fallback` マップへの追記

```dart
'hedra': '''## Hedra AI
リアルタイム会話型アバター動画プラットフォーム。
Character-3 (オムニモーダルモデル) で業界最高精度の口唇同期。
a16z \$44M調達・3M+ユーザー・\$0.05/分の低価格。''',

'heygen': '''## HeyGen
ビジネス向けAIアバター動画の世界標準。
15秒録画→スタジオ品質・175言語翻訳・MCP統合対応。
G2 2025年最速成長製品賞 #1・100K+企業採用。''',
```

### 3. `_quizzes` マップへの追記 (任意)

```dart
'hedra': [
  QuizQuestion(
    question: 'Hedra AI の Character-3 の最大の特徴は何ですか？',
    options: ['高解像度画像生成', '音声・画像・テキストを同時処理するオムニモーダルAI', '最安値の動画生成', '最多言語対応'],
    correctIndex: 1,
    explanation: 'Character-3は画像・テキスト・音声を1つのモデルで同時処理するオムニモーダルAI。従来の3ステップパイプラインより自然で高精度。',
  ),
],
'heygen': [
  QuizQuestion(
    question: 'HeyGen が対応している言語数はどのくらいですか？',
    options: ['30言語', '50言語', '100言語', '175言語'],
    correctIndex: 3,
    explanation: 'HeyGenは175言語でリップシンク動画翻訳が可能。同じアバターで世界中の言語に対応できる。',
  ),
],
```

## 確認事項

- migration: `20260417094000_seed_hedra_ai_university.sql` (hedra, 4 records)
- migration: `20260417095000_seed_heygen_ai_university.sql` (heygen, 4 records)
- プロバイダーリスト: CLAUDE.md + COMPRESSED_PROMPT_V3.md 両方更新済み (70社)
- flutter analyze 0エラー確認後 commit してください
