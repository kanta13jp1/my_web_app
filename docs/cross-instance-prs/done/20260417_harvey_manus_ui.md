---
date: 2026-04-17
from: Windowsアプリ版#68
to: VSCode版
status: done
priority: medium
---

# Harvey AI + Manus AI の UI追加依頼

## 概要

AI大学67-68社目として Harvey AI と Manus AI のmigrationを追加済み。
VSCode版で `lib/pages/gemini_university_v2_page.dart` の以下2箇所に追記してください。

## 追加内容

### 1. `_providerMeta` マップへの追記

```dart
'harvey': ProviderMeta(
  displayName: 'Harvey AI',
  emoji: '⚖️',
  color: Color(0xFF2C5282), // 法律・信頼 → ディープブルー
  description: '法律・プロフェッショナルサービス特化AI',
),
'manus': ProviderMeta(
  displayName: 'Manus AI',
  emoji: '🤖',
  color: Color(0xFF553C9A), // エージェント・自律 → パープル
  description: '世界初の汎用AIエージェント (Meta傘下)',
),
```

### 2. `_fallback` マップへの追記

```dart
'harvey': '''## Harvey AI
法律・プロフェッショナルサービス特化AIプラットフォーム。
A&O Shearman・PwCなど世界トップ法律事務所が採用。評価額\$11B (2026年)。
契約レビュー・法的リサーチ・デューデリジェンスを自動化。''',

'manus': '''## Manus AI
世界初の真の汎用AIエージェント。Meta買収(\$2-3B)済み。
Webブラウジング・コード実行・ファイル操作を自律的にこなす。
「AIが実際に仕事をする」新パラダイムを切り開いた。''',
```

### 3. `_quizzes` マップへの追記 (任意)

```dart
'harvey': [
  QuizQuestion(
    question: 'Harvey AIが最も強みを持つ分野はどれですか？',
    options: ['ゲーム開発', '法律・リーガルサービス', '医療診断', '動画生成'],
    correctIndex: 1,
    explanation: 'Harveyは法律事務所・企業法務・監査法人向けに特化したAI。Am Law 100の50%以上が採用。',
  ),
],
'manus': [
  QuizQuestion(
    question: 'Manus AIの最大の特徴は何ですか？',
    options: ['画像生成の高品質さ', 'コード補完の速さ', '複雑タスクの自律実行', '音声合成の自然さ'],
    correctIndex: 2,
    explanation: 'Manusはタスクを計画・分解・並列実行できる汎用エージェント。従来のAIが"教える"のに対し、Manusは"実行する"。',
  ),
],
```

## 確認事項

- migration: `20260417092000_seed_harvey_ai_university.sql` (harvey, 4 records)
- migration: `20260417093000_seed_manus_ai_university.sql` (manus, 4 records)
- プロバイダーリスト: CLAUDE.md + COMPRESSED_PROMPT_V3.md 両方更新済み
- flutter analyze 実行後、0エラーを確認してcommitしてください
