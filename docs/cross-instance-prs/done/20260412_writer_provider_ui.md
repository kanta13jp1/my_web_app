---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Writer プロバイダー UI 追加依頼

## 背景

Windows版#47 で Writer を AI大学 25社目として追加しました。
migration 適用済み: `supabase/migrations/20260412016000_seed_writer_ai_university.sql`

Note: provider キーは `writer` (そのまま) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Writer を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'writer': {
  'name': 'Writer',
  'emoji': '✍️',
  'color': Color(0xFF7C3AED),  // Writer brand purple
  'description': 'Palmyra / ビジネスAI',
},
```

### 2. `_fallback` マップに追加

```dart
'writer': '''
# Writer — エンタープライズビジネスAI

Writer はビジネス文書生成・コンプライアンス管理に特化したエンタープライズAI企業です。
独自の Palmyra LLM はマーケティング・法務・HR・営業文書の品質で汎用LLMを上回ります。

## モデルラインナップ
- Palmyra X 004 (128K, 最高精度・長文書処理)
- Palmyra X 003 Instruct (32K, 高速・マーケティング用途)
- Palmyra Med (医療特化)
- Palmyra Fin (金融特化)

## 特徴
- Knowledge Graph: 社内文書をRAGに自動統合
- ブランドボイス学習: 企業の表現スタイルをAIに記憶させ一貫性を担保
- SOC2/HIPAA/GDPR準拠

[Writer Docs](https://dev.writer.com/docs)
''',
```

### 3. `_quizzes` マップに追加

```dart
'writer': [
  {
    'question': 'Writer の Palmyra Med / Palmyra Fin はどのような特化モデルですか？',
    'options': ['医療・金融ドメインに特化したビジネス文書生成モデル', '音声認識専用モデル', '画像生成専用モデル', 'コード生成専用モデル'],
    'answer': 0,
    'explanation': 'Palmyra Med は医療・ヘルスケア文書に、Palmyra Fin は財務・金融文書に特化したモデルです。それぞれのドメイン用語・コンプライアンス要件に最適化されています。',
  },
  {
    'question': 'Writer の Knowledge Graph の主な役割は？',
    'options': ['社内文書をインデックス化してRAGに活用', 'モデルのトレーニングデータ管理', 'APIレート制限の管理', '画像ファイルの保存'],
    'answer': 0,
    'explanation': 'Writer の Knowledge Graph は社内のPDF・Word・Notion等の文書を自動インデックス化し、AIが参照できるRAGシステムとして機能します。企業固有の情報に基づいた回答生成が可能になります。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'✍️'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
