---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# Amazon (Bedrock/Nova) プロバイダー UI 追加依頼

## 背景

Windows版#35 で Amazon Bedrock / Nova を AI大学 12社目として追加しました。
migration 適用済み: `supabase/migrations/20260412003000_seed_amazon_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Amazon を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'amazon': {
  'name': 'Amazon',
  'emoji': '🟠',
  'color': Color(0xFFFF9900),  // Amazon brand orange
  'description': 'Bedrock / Nova',
},
```

### 2. `_fallback` マップに追加

```dart
'amazon': '''
# Amazon Bedrock / Nova — マルチモデル AI プラットフォーム

Amazon Bedrock は 50+ モデルを単一 API で利用できる AWS のマネージドサービスです。
2024年末発表の Amazon Nova は AWS 独自の大規模言語モデルシリーズです。

## Amazon Nova シリーズ
- Nova Micro (テキスト特化・超低コスト)
- Nova Lite (マルチモーダル・低コスト)
- Nova Pro (高精度マルチモーダル)
- Nova Premier (1M コンテキスト・最高精度)
- Nova Canvas (画像生成)
- Nova Reel (動画生成・最大2分)

## 特徴
- AWS VPC/IAM/CloudTrail との完全統合
- エンタープライズ SLA (HIPAA/SOC2/GDPR)
- Converse API で全モデルを統一インターフェースで利用可能

[AWS Console](https://console.aws.amazon.com/bedrock/)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'amazon': [
  {
    'question': 'Amazon Bedrock の Converse API の主な利点は何ですか？',
    'options': ['全モデルを統一インターフェースで利用可能', '最高速度の推論', '最低コストの利用', '日本語専用最適化'],
    'answer': 0,
    'explanation': 'Converse API は Claude / Nova / Llama など異なるモデルを同一コードで切り替えられる統一インターフェースです。',
  },
  {
    'question': 'Amazon Nova Premier の最大コンテキスト長は？',
    'options': ['1M トークン', '300K トークン', '128K トークン', '32K トークン'],
    'answer': 0,
    'explanation': 'Nova Premier は 1M (100万) トークンのコンテキストウィンドウを持つ最上位モデルです。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🟠'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
