---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Baidu ERNIE プロバイダー UI 追加依頼

## 背景

Windows版#41 で Baidu (ERNIE Bot / 文心一言) を AI大学 18社目として追加しました。
migration 適用済み: `supabase/migrations/20260412009000_seed_baidu_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Baidu を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'baidu': {
  'name': 'Baidu ERNIE',
  'emoji': '🔴',
  'color': Color(0xFF2932E1),  // Baidu brand blue
  'description': 'ERNIE Bot / 中国最大 AI',
},
```

### 2. `_fallback` マップに追加

```dart
'baidu': '''
# Baidu ERNIE — 中国最大の AI プラットフォーム

中国版 ChatGPT として数千万ユーザーを獲得した ERNIE Bot の API。
中国語処理において世界最高水準の精度を誇り、グローバル企業の中国展開に必須。

## 主要モデル
- ERNIE 4.0 Ultra: 最高精度・128K コンテキスト
- ERNIE 4.0 Turbo: 高速バランス型
- ERNIE Speed: 低コスト大量処理
- ERNIE Lite: 完全無料

## 特徴
- 中国語理解・生成で圧倒的優位
- 知識グラフ統合 (5.5億エンティティ)
- qianfan SDK: pip install qianfan で即利用

[Baidu AI Cloud](https://cloud.baidu.com/)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'baidu': [
  {
    'question': 'Baidu の AI チャットサービス ERNIE Bot の中国語名は？',
    'options': ['文心一言', '通义千问', '讯飞星火', '混元'],
    'answer': 0,
    'explanation': '文心一言 (Wénxīn Yīyán) は Baidu が2023年に公開した AI チャットサービスで、中国版 ChatGPT として数千万ユーザーを獲得しています。',
  },
  {
    'question': 'Baidu ERNIE が特に優れている言語は？',
    'options': ['中国語', '英語', '日本語', 'スペイン語'],
    'answer': 0,
    'explanation': 'ERNIE は知識グラフと LLM を組み合わせた設計により、中国語の理解・生成において世界最高水準の精度を持っています。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🔴'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: done` を `status: done` に変更してください。
