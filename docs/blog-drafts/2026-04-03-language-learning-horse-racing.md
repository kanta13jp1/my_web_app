---
title: "Flutter Web × Supabase で Duolingo競合・競馬AIパイプライン・CRM管理を1日で実装した話"
tags: Flutter,Supabase,個人開発,buildinpublic,AI予想
published: true
---

# ブログ下書き 2026-04-03 — 2026-04-03-language-learning-horse-racing

## タイトル案

1. Flutter Web × Supabase で Duolingo 風・競馬予測AI・CRM を同時実装した話
2. SM-2 間隔反復アルゴリズムを Flutter で実装してワンタップ語学学習機能を作った
3. 21競合 SaaS に挑む自分株式会社: netkeiba・Duolingo・Salesforce 相当機能を1日で実装

## 投稿先候補

- [x] Zenn
- [x] Qiita
- [ ] note
- [ ] dev.to (英語版)
- [ ] Hashnode
- [ ] X Article

## 本文下書き (技術ブログ)

### はじめに

自分株式会社は、Notion・Evernote・MoneyForward・Slack など 21 の競合サービスを
1 つのプラットフォームで超えることを目指して Flutter Web + Supabase で毎日開発を続けています。

本日 2026-04-03 の daily-development では以下を実装しました:

- **語学学習ページ** (Duolingo/Anki 競合): SM-2 間隔反復アルゴリズム・フラッシュカード・ストリーク管理
- **Edge Function Summary Card 修正**: recipe-meal-planner・travel-itinerary-planner・spreadsheet-database の実装済みマークを正確に更新

### 語学学習機能の実装

`language-learning` Edge Function はすでに実装済みでした。
今回はフロントエンド (`language_learning_page.dart`) を新規作成しました。

#### 構成

```
LanguageLearningPage
├── Tab 1: 単語帳一覧
│   ├── 連続学習ストリークバナー (🔥 N日連続)
│   ├── 単語帳リスト (language_from → language_to)
│   └── 選択中の単語帳カード一覧
├── Tab 2: フラッシュカードレビュー
│   ├── LinearProgressIndicator (進捗)
│   ├── フラッシュカード (表/裏 アニメーション)
│   └── 覚えた！/ もう一度 ボタン
└── Tab 3: 統計
    ├── ストリーク (🔥 N日連続・最長記録)
    ├── 統計グリッド (単語帳数/総カード/総レビュー/正解率)
    └── 学習のコツカード
```

#### SM-2 間隔反復アルゴリズム

Edge Function 側で SM-2 アルゴリズムを実装しています。

```typescript
// SM-2 アルゴリズム (Edge Function 側)
const q = quality; // 回答品質 0-5
if (correct) {
  if (interval === 1) interval = 6;
  else interval = Math.round(interval * ease);
  ease = ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (ease < 1.3) ease = 1.3;
} else {
  interval = 1; // 不正解は1日後に再レビュー
}
const nextReview = new Date(Date.now() + interval * 86400000).toISOString();
```

#### Flutter UI での注意点

今回も `require_trailing_commas` と `unnecessary_const` のルールに注意が必要でした。

```dart
// NG: trailing comma なし
Text('テキスト', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),

// OK: trailing comma あり
Text(
  'テキスト',
  textAlign: TextAlign.center,
  style: TextStyle(color: Colors.grey),
),
```

また、`const` キーワードは既に const コンテキスト内では不要です:

```dart
// NG: unnecessary_const
style: const TextStyle(color: Colors.grey), // const コンテキスト内で const が不要

// OK
style: TextStyle(color: Colors.grey),
```

### Edge Function Summary Card の重複エントリ修正

`edge_function_summary_card.dart` に重複エントリが発生していました:

- `recipe-meal-planner`: 実装済みなのに `false` → `true` に修正
- `travel-itinerary-planner`: 重複エントリ (false + true) → false を削除
- `spreadsheet-database`: 重複エントリ (false + true) → false を削除

また新しく実装した機能のエントリを追加:

```dart
_FnDef('horse-racing-predictor', '競馬予測 AI (netkeiba競合)', true, '/horse-racing', '競馬予測AIページ'),
_FnDef('language-learning', '語学学習 (Duolingo競合)', true, '/language-learning', '語学学習ページ'),
_FnDef('crm-sales-pipeline', 'CRM セールスパイプライン', true, '/crm-pipeline', 'CRM パイプラインページ'),
```

### まとめ

- `flutter analyze` 0エラーを維持
- 語学学習機能 (Duolingo競合) を新規実装
- 21競合 SaaS のうち新たに「Duolingo」カテゴリをカバー

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #DartLang
