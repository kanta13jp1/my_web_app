---
title: "Flutter Web でWiki・タイムトラッカー・音声メモを1日で同時実装した話"
tags: Flutter,Supabase,個人開発,buildinpublic,音声認識
published: true
---

# ブログ下書き 2026-04-02 — 2026-04-02-wiki-timetracker-voicememo

## タイトル案

1. Flutter WebでWiki・勤怠・音声メモを同時実装 — Notion/ジョブカン/Google Keepに挑む3機能を1日で作った話
2. 自分株式会社が Notion・ジョブカン・Google Keep を1日で超えにいった話 — Flutter Web 3機能同時実装
3. Edge Functionと連携するFlutter Webページを1日3本量産する方法 — Wiki/TimeTracker/VoiceMemo実装記

## 投稿先候補

- [x] Zenn
- [x] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article

## 本文下書き (約2000字)

### はじめに

自分株式会社（[https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)）は、21の競合SaaSを超えることを目指して毎日機能を追加しているFlutter Web + Supabaseアプリです。

本日（2026-04-02）の実装では、以下の3機能を一気に追加しました。

- **Wiki・データベース** — Notion/Confluence競合。階層型Wikiページ + テーブルビュー
- **勤怠・時間追跡** — ジョブカン/Toggl/Clockify競合。出退勤打刻 + プロジェクト別時間管理
- **音声メモ・文字起こし** — Google Keep/LINE/Discord競合。音声メモ + AI要約 + ノート変換

すべてのページはSupabase Edge Functionと連携するEdge Function Firstアーキテクチャで実装しました。

---

### 実装方法

#### 共通パターン: Edge Function First

すべてのページは同じパターンで実装しています。

```dart
Future<void> _fetchData() async {
  setState(() => _isLoading = true);
  try {
    final response = await _supabase.functions.invoke(
      'edge-function-name',
      queryParameters: {'view': 'list'},
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data['items'] is List) {
      setState(() => _items = (data['items'] as List).cast<Map<String, dynamic>>());
    }
  } catch (e) {
    setState(() => _errorMessage = 'データの取得に失敗: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

フロントエンドはUIに集中、ロジックはEdge Functionに任せるシンプルな設計です。

#### WikiDatabasePage — 階層型Wikiの実装

Notion競合の中でも最難関の「階層型ページ構造」を実装しました。

```dart
// ページ詳細取得 (子ページ + テーブルデータを並行取得)
Future<void> _fetchPageDetail(String pageId) async {
  final response = await _supabase.functions.invoke(
    'wiki-database',
    queryParameters: {'view': 'page', 'page_id': pageId},
  );
  // pageとchildren、tableRowsをまとめて取得
}
```

TabBarViewの2タブ構成（ページ一覧 / ページ詳細）で、ページを選択するとタブが自動で切り替わります。

#### TimeTrackerPage — 勤怠管理の実装

ジョブカン競合の「出退勤打刻」と「プロジェクト別時間管理」を実装しました。

ポイントは `SegmentedButton` による今日/今週/今月の切り替えです。

```dart
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'today', label: Text('今日')),
    ButtonSegment(value: 'week', label: Text('今週')),
    ButtonSegment(value: 'month', label: Text('今月')),
  ],
  selected: {_view},
  onSelectionChanged: (s) {
    setState(() => _view = s.first);
    _fetchEntries();
  },
),
```

残業アラート (`overtimeAlert: true`) が返ってきたときはオレンジのバナーで警告を出します。

プロジェクト別時間集計はバーグラフで可視化。最大値に対する比率で `LinearProgressIndicator` の幅を決めます。

```dart
final ratio = maxHours > 0 ? hours / maxHours : 0.0;
LinearProgressIndicator(
  value: ratio.toDouble(),
  valueColor: AlwaysStoppedAnimation<Color>(color),
)
```

#### VoiceMemoTranscriberPage — 音声メモの実装

音声メモはExpansionTileで展開するとAI要約と文字起こしが表示される設計にしました。

検索機能はEdge Function側で `?view=search&q=キーワード` として処理します。

```dart
Future<void> _searchMemos(String q) async {
  final response = await _supabase.functions.invoke(
    'voice-memo-transcriber',
    queryParameters: {'view': 'search', 'q': q.trim()},
  );
}
```

「ノートに変換」ボタンでAI要約 + 文字起こしをMarkdown形式で `notes` テーブルに保存できます。

---

### 詰まったポイント

#### trailing comma (require_trailing_commas) との戦い

Flutter analyzeで `require_trailing_commas` が有効になっているため、複数行のウィジェットは必ず末尾にカンマが必要です。

特に三項演算子の中でTextウィジェットを使うときに忘れがちです。

```dart
// NG
subtitle: Text(
  longText,
  style: const TextStyle(fontSize: 12)), // ← カンマ不足

// OK
subtitle: Text(
  longText,
  style: const TextStyle(fontSize: 12),
), // ← 正しい
```

#### DropdownButtonFormField.value → initialValue への移行

Flutter 3.33+で `DropdownButtonFormField.value` が deprecated になりました。`initialValue` に変更する必要があります。

```dart
// NG (deprecated)
DropdownButtonFormField<String>(value: _selectedStyle, ...)

// OK
DropdownButtonFormField<String>(initialValue: _selectedStyle, ...)
```

---

### まとめ

本日の実装で自分株式会社のページ数は150ページ以上、Edge Function数は238本体制になりました。

「競合21社を超える」という目標に向けて、毎日1〜3機能をEdge Function Firstで実装しています。

flutter analyze 0件を維持しながら高速に機能追加できるのは、Edge Functionへのロジック移行を徹底しているためです。

サービスURL: [https://my-web-app-b67f4.web.app/](https://my-web-app-b67f4.web.app/)

#FlutterWeb #Supabase #buildinpublic #Notion代替 #ジョブカン代替
