---
title: "Flutter Performance Optimization — Reduce Widget Rebuilds, Lazy Loading, and Memoization"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Performance Optimization — Reduce Widget Rebuilds, Lazy Loading, and Memoization

The three root causes of jank and how to fix each one.

## Cause 1: Unnecessary Widget Rebuilds

```dart
// ❌ Bad: the whole parent rebuilds every time
class ParentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // All children rebuild every time
    return Column(children: [
      Text(DateTime.now().toString()), // changes every second
      ExpensiveWidget(),               // rebuilds every second → wasted
    ]);
  }
}

// ✅ Good: cache immutable widgets with const
class ParentWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TimerText(),              // isolated StatefulWidget
      const ExpensiveWidget(),  // completely skipped with const
    ]);
  }
}
```

## Cause 2: Building All List Items at Once

```dart
// ❌ Bad: builds all items upfront
ListView(
  children: items.map((item) => ItemCard(item: item)).toList(),
)

// ✅ Good: builds only visible items
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemCard(item: items[index]),
)

// Even better: slivers for complex scrolling
CustomScrollView(
  slivers: [
    SliverAppBar(pinned: true, title: const Text('Title')),
    SliverList.builder(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => ItemCard(item: items[i]),
        childCount: items.length,
      ),
    ),
  ],
)
```

## Cause 3: Repeating Expensive Computations

```dart
// ❌ Bad: sorts inside build() on every rebuild
@override
Widget build(BuildContext context) {
  final sorted = items.sorted(...); // O(n log n) every time
  return ListView.builder(...);
}

// ✅ Good: useMemoized recomputes only when dependencies change (hooks)
final sorted = useMemoized(
  () => items.sorted(...),
  [items],
);

// With Riverpod
final sortedItemsProvider = Provider<List<Item>>((ref) {
  final items = ref.watch(itemsProvider);
  return items.sorted(...); // recomputes only when items changes
});
```

## Measure with Flutter DevTools

```bash
flutter run --profile
# DevTools → Performance → Record → Identify jank frames
# Widget Rebuild Stats → see how many times widgets rebuild
```

## Summary

```
const widgets    → completely skip immutable subtrees
ListView.builder → build only visible items (60fps with millions of rows)
Memoization      → cache heavy computation with Provider / useMemoized
Measure first    → profile before optimizing; don't guess the bottleneck
```

Apply optimizations only where DevTools shows a real bottleneck. Premature optimization is the enemy.
