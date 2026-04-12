---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# IBM watsonx プロバイダー UI 追加依頼

## 背景

Windows版#39 で IBM watsonx (エンタープライズAI・Granite OSS) を AI大学 16社目として追加しました。
migration 適用済み: `supabase/migrations/20260412007000_seed_ibm_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に IBM を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'ibm': {
  'name': 'IBM watsonx',
  'emoji': '🔵',
  'color': Color(0xFF0F62FE),  // IBM brand blue
  'description': 'Granite OSS / エンタープライズ AI',
},
```

### 2. `_fallback` マップに追加

```dart
'ibm': '''
# IBM watsonx — エンタープライズ AI の老舗

金融・医療・公共機関での導入実績が豊富な企業向け AI プラットフォーム。
Granite LLM は Apache 2.0 で OSS 公開されており、商用利用・ファインチューニング可能。

## 主要コンポーネント
- watsonx.ai: モデル構築・デプロイ・推論
- watsonx.data: ガバナンス付きデータレイク
- watsonx.governance: AI 監査・バイアス検出
- Granite: IBM 独自 OSS モデル (テキスト・コード生成)

## 特徴
- 東京リージョン対応・データ主権要件に対応
- HIPAA/GDPR/ISO27001 準拠
- OpenAI 互換 API で移行容易

[watsonx.ai](https://cloud.ibm.com/watsonx)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'ibm': [
  {
    'question': 'IBM Granite モデルのオープンソースライセンスは？',
    'options': ['Apache 2.0', 'MIT', 'GPL v3', 'CC BY-NC'],
    'answer': 0,
    'explanation': 'IBM Granite は Apache 2.0 ライセンスで公開されており、商用利用・改変・ファインチューニングが自由に行えます。',
  },
  {
    'question': 'IBM watsonx が特に強みを持つ業界は？',
    'options': ['金融・医療・公共機関', 'ゲーム・エンタメ', 'EC・小売', 'スタートアップ'],
    'answer': 0,
    'explanation': 'IBM watsonx は HIPAA/GDPR などの厳しいコンプライアンス要件がある金融・医療・公共機関での導入実績が豊富です。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🔵'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
