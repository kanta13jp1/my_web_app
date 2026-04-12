---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Aleph Alpha プロバイダー UI 追加依頼

## 背景

Windows版#45 で Aleph Alpha を AI大学 21社目として追加しました。
migration 適用済み: `supabase/migrations/20260412012000_seed_aleph_alpha_ai_university.sql`

Note: provider キーは `aleph_alpha` (アンダースコア区切り) です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Aleph Alpha を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'aleph_alpha': {
  'name': 'Aleph Alpha',
  'emoji': '🇩🇪',
  'color': Color(0xFF1A1A2E),  // Dark navy (Aleph Alpha brand)
  'description': 'Luminous / Pharia',
},
```

### 2. `_fallback` マップに追加

```dart
'aleph_alpha': '''
# Aleph Alpha — 欧州AI主権のリーダー

Aleph Alpha は2020年にドイツで創業。ドイツ政府・EU機関が採用する
GDPR完全準拠のエンタープライズAIプラットフォームです。

## モデルラインナップ
- Pharia-1-LLM-7B (OpenAI互換・次世代)
- Luminous Supreme 70B (最高精度)
- Luminous Extended 30B (バランス型)
- Luminous Base 13B (微調整ベース)

## 特徴
- AtMan技術でモデルの推論根拠をトークン単位で可視化 (説明可能AI)
- データはドイツ国内のみで処理 — EU外への転送なし
- GDPR・NIS2・EU AI Act 完全準拠

[Aleph Alpha Docs](https://docs.aleph-alpha.com/)
''',
```

### 3. `_quizzes` マップに追加

```dart
'aleph_alpha': [
  {
    'question': 'Aleph Alpha が開発した「説明可能AI」技術の名称は？',
    'options': ['AtMan', 'SHAP', 'LIME', 'Grad-CAM'],
    'answer': 0,
    'explanation': 'AtMan (Attention Manipulation) は Aleph Alpha 独自の技術で、モデルがどのトークンに注目して推論したかをトークン単位で可視化できます。',
  },
  {
    'question': 'Aleph Alpha が欧州規制対応を強みとする主な理由は？',
    'options': ['データがドイツ国内のみで処理されGDPR完全準拠', '最大のモデルパラメータ数', '最低コストのAPI', '最速の推論速度'],
    'answer': 0,
    'explanation': 'Aleph Alpha はデータをドイツ国内のデータセンターのみで処理し、EU外への転送を行わないため、GDPR・EU AI Actに完全準拠しています。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🇩🇪'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
