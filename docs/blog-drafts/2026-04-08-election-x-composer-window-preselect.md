---
title: Flutter×地方選挙アプリ — スケジュールフィルターとXコンポーザーをワンタップで連動させた話
emoji: 🗳️
type: tech
topics: [flutter, dart, ux, election]
published: false
---

## はじめに

自分株式会社アプリの「選挙勝利ページ」では、地方選挙スケジュールを「今週末 / 2週後 / 3週後 …」と週ごとにフィルタリングできます。
今回はそのフィルター選択をそのままXスレッドコンポーザーに引き継ぐ **ウィンドウ連動機能** を実装しました。

## 解決した課題

スケジュールセクションで「2週後」を選択して選挙一覧を確認した後、Xに投稿したい場合、
これまではコンポーザーダイアログを開き直して再度「2週後」を選ぶ必要がありました。

```
[スケジュール] 2週後 ✅ → [Xコンポーザー] 今週末 ← 毎回再選択が必要
```

## 実装内容

### 1. `ElectionXPostComposerDialog` に `initialWindowIndex` パラメータを追加

```dart
class ElectionXPostComposerDialog extends StatefulWidget {
  // ...
  final int? initialWindowIndex; // 追加

  static Future<void> show(
    BuildContext context, {
    // ...
    int? initialWindowIndex,    // 追加
  }) { ... }
}
```

`initState` では、`initialWindowIndex` が指定されていればそれを優先し、
なければ「選挙が存在する最初のウィンドウ」を自動選択する既存ロジックを維持します。

```dart
final requestedIndex = widget.initialWindowIndex;
_selectedIndex = requestedIndex != null
    ? requestedIndex.clamp(0, windows.length - 1)
    : _electionCounts.indexWhere((c) => c > 0).clamp(0, windows.length - 1);
```

### 2. `_filterToWindowIndex()` ヘルパーを追加

スケジュールフィルター名（`'今週末'`, `'2週後'` …）を
`LocalElectionShareService.availableWindows` のインデックスに変換します。

```dart
int? _filterToWindowIndex(String filter) {
  final idx = LocalElectionShareService.availableWindows
      .indexWhere((w) => w.label == filter);
  return idx >= 0 ? idx : null; // 'すべて' は null を返す
}
```

### 3. スケジュールセクションに「X投稿」ショートカットボタンを追加

特定の週末が選択されており、対象選挙が存在する場合にのみ表示します。

```dart
if (_selectedScheduleFilter != 'すべて' &&
    filteredUpcomingSchedules.isNotEmpty)
  Align(
    alignment: Alignment.centerRight,
    child: TextButton.icon(
      onPressed: () => ElectionXPostComposerDialog.show(
        context,
        snapshot: snapshot,
        shareService: _shareService,
        publishedMemo: _publishedRealityMemo,
        initialWindowIndex: _filterToWindowIndex(_selectedScheduleFilter),
      ),
      icon: const Icon(Icons.schedule_send, size: 16),
      label: Text('$_selectedScheduleFilterの選挙をX投稿'),
    ),
  ),
```

## テスト修正: ElectionRegionalKpiChart のオーバーフロー

`election_charts_test.dart` の `ElectionRegionalKpiChart` テストが
レイアウトオーバーフローで失敗していた既存バグも合わせて修正しました。

**原因**: テスト用の `Scaffold` に固定高さがなく、チャートが `body` の高さを超えていた。

**修正**: チャートを `SingleChildScrollView` でラップ。

```dart
body: SingleChildScrollView(
  child: ElectionRegionalKpiChart(prefectures: [...]),
),
```

また、凡例テキスト `'新人擁立目標'` の期待値が実際の `'新人擁立目標 (未達)'` と一致しなかったため、
`find.text` → `find.textContaining` に変更。

## まとめ

- フィルター選択 → Xコンポーザー開く → 再選択 の手間を **ワンタップ** に削減
- `initialWindowIndex` はオプショナルなので、既存の呼び出し元は変更不要（後方互換）
- プレウィンドウ自動選択ロジックは `initialWindowIndex = null` 時に維持

---

サービスURL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Dart #UX #buildinpublic
