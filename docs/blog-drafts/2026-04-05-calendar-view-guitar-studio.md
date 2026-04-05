---
title: Flutter WebでTableCalendarによるカレンダービューと、ギタースタジオのshare_plus連携を実装した話
emoji: 📅
type: tech
topics: [flutter, supabase, dart, calendar, flutterweb]
published: false
---

# Flutter WebでTableCalendarによるカレンダービューと、ギタースタジオのshare_plus連携を実装した話

## はじめに

今日は自分株式会社（Flutter Web + Supabase で21競合SaaSを超えるAI統合プラットフォーム）の開発で行った2つの実装を解説します。

1. **カレンダービュー（Notion Database parity）**
   `table_calendar` パッケージを使った月次カレンダーUIと、`calendar-events` Edge Functionとの連携

2. **ギタースタジオのflutter analyze 0エラー維持**
   `share_plus` 連携コードの `use_build_context_synchronously` エラー修正

---

## 1. TableCalendarによるカレンダービュー実装

### なぜカレンダービューが必要か

Notionの機能ギャップ分析（現在カバー率94%）の中で「カレンダービュー」は長期ロードマップに位置づけられていましたが、既存の `calendar-events` Edge Functionと `table_calendar: ^3.1.2` パッケージが既に揃っていたため実装のコストが低いと判断しました。

### 実装のポイント

#### 1. 日付キーによるイベントマッピング

```dart
final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};

static String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
```

`TableCalendar` の `eventLoader` は `DateTime day` を受け取るため、`YYYY-MM-DD` 文字列をキーにしたMapに変換します。これにより O(1) で日付別イベントを取得できます。

#### 2. ページ変更時の月次フェッチ

```dart
onPageChanged: (focusedDay) {
  _focusedDay = focusedDay;
  _fetchMonth(focusedDay);
},
```

ページスワイプ時に対象月のイベントをEdge Functionから取得します。既に取得済みの月のデータは `_eventsByDate` に蓄積されるため、戻ったときの再取得を抑制できます。

#### 3. Edge FunctionへのGETリクエスト

```dart
final res = await _supabase.functions.invoke(
  'calendar-events',
  method: HttpMethod.get,
  queryParameters: {
    'view': 'month',
    'year': month.year.toString(),
    'month': month.month.toString(),
  },
);
```

`supabase_flutter` の `functions.invoke` は `HttpMethod.get` と `queryParameters` を組み合わせることでGETリクエストを送れます。

#### 4. 色選択UI（色彩ピッカー）

```dart
Wrap(
  spacing: 8,
  children: colors.map((c) => GestureDetector(
    onTap: () => setDialogState(() => selectedColor = c),
    child: Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: Color(int.parse('FF${c.replaceFirst('#', '')}', radix: 16)),
        shape: BoxShape.circle,
        border: selectedColor == c
            ? Border.all(color: Colors.black87, width: 2.5)
            : null,
      ),
    ),
  )).toList(),
),
```

外部パッケージなしで5色のカラーピッカーを実装しました。

---

## 2. ギタースタジオのflutter analyze修正

### 問題1: `use_build_context_synchronously`

```dart
// 修正前
final message = ...;
ScaffoldMessenger.of(context).showSnackBar(...);  // ← async gap後にcontextを使用

// 修正後
final message = ...;
if (!mounted) return;  // ← mounted チェックを追加
ScaffoldMessenger.of(context).showSnackBar(...);
```

`await` 後に `BuildContext` を使う場合は必ず `mounted` チェックが必要です。

### 問題2: `undefined_identifier`

```dart
// 修正前（_audioLevelが未定義）
final level = _audioLevel;

// 修正後（フィールドを宣言）
final double _audioLevel = 0.0;
```

`prefer_final_fields` ルールにより、変更されないフィールドは `final` にする必要があります。

### 問題3: `unnecessary_import`

```dart
// 修正前
import 'package:cross_file/cross_file.dart';  // share_plusが再エクスポートするため不要
import 'package:share_plus/share_plus.dart';

// 修正後
import 'package:share_plus/share_plus.dart';  // cross_file不要
```

`share_plus` パッケージが `cross_file` の `XFile` クラスを再エクスポートするため、直接インポートは不要です。

---

## まとめ

- `flutter analyze 0エラー` 維持は CI品質の最低ラインとして厳格に守る
- Notionパリティ機能（カレンダービュー）は長期ロードマップでも既存インフラが揃っていれば早期着手できる
- `mounted` チェックは async gap後のcontext使用に必須
- `prefer_final_fields` は宣言後に変更しないフィールドに `final` を強制

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #TableCalendar
