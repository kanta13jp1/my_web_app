---
title: "Flutter パフォーマンス最適化 — Widget リビルド削減・遅延ロード・メモ化"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter パフォーマンス最適化 — Widget リビルド削減・遅延ロード・メモ化

jank (コマ落ち) を引き起こす 3 大原因と解決策を解説する。

## 原因 1: 不要な Widget リビルド

```dart
// ❌ 悪い例: 親全体が毎回リビルド
class ParentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 全子ウィジェットが毎回再構築される
    return Column(children: [
      Text(DateTime.now().toString()), // 毎秒変わる
      ExpensiveWidget(),               // 毎秒リビルド → 無駄
    ]);
  }
}

// ✅ 良い例: const で不変ウィジェットをキャッシュ
class ParentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TimerText(),              // 独立した StatefulWidget
      const ExpensiveWidget(),  // const で完全スキップ
    ]);
  }
}
```

## 原因 2: 大きなリストの一括構築

```dart
// ❌ 悪い例: 全アイテムを一度に構築
ListView(
  children: items.map((item) => ItemCard(item: item)).toList(),
)

// ✅ 良い例: 表示領域のみ構築
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemCard(item: items[index]),
)

// さらに高性能: スライバーで複合スクロール
CustomScrollView(
  slivers: [
    SliverAppBar(pinned: true, title: const Text('タイトル')),
    SliverList.builder(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => ItemCard(item: items[i]),
        childCount: items.length,
      ),
    ),
  ],
)
```

## 原因 3: 重い計算の繰り返し

```dart
// ❌ 悪い例: build() の中で毎回ソート
@override
Widget build(BuildContext context) {
  final sorted = items.sorted(...); // O(n log n) 毎回
  return ListView.builder(...);
}

// ✅ 良い例: useMemoized で依存値が変わった時だけ再計算 (hooks)
final sorted = useMemoized(
  () => items.sorted(...),
  [items],
);

// Riverpod の場合
final sortedItemsProvider = Provider<List<Item>>((ref) {
  final items = ref.watch(itemsProvider);
  return items.sorted(...); // items が変わった時だけ再計算
});
```

## Flutter DevTools で計測

```bash
flutter run --profile
# DevTools → Performance → Record → Identify Jank frames
# Widget Rebuild Stats → 何回リビルドされているか確認
```

## まとめ

```
const 活用       → 不変ウィジェットの完全スキップ
ListView.builder → 表示範囲のみ構築 (万件でも60fps維持)
メモ化           → 重い計算は Provider / useMemoized でキャッシュ
計測優先         → 推測より DevTools でボトルネック特定
```

最適化は「計測して見つけた箇所だけ」に適用する。早すぎる最適化は禁物。
