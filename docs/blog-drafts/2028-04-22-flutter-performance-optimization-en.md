---
title: "Flutter Performance Optimization: const, Lazy Loading, and Image Caching"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Performance Optimization: const, Lazy Loading, and Image Caching

Three rules for perceived speed. Always measure with DevTools first.

## 1. const: Minimize Rebuilds

`const` constructors tell Flutter to skip rebuilding a widget during tree
reconstruction. It's one of the cheapest performance wins available.

```dart
// Bad: rebuilt every time parent rebuilds
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Title'),
        Icon(Icons.star),
        TaskList(),
      ],
    );
  }
}

// Good: static widgets are const — rebuild skipped
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text('Title'),
        Icon(Icons.star),
        TaskList(),
      ],
    );
  }
}
```

**Catch missing `const` with `flutter analyze`**:

```bash
flutter analyze lib/ | grep "const"
# prefer_const_constructors warning flags every missed opportunity
```

## 2. Lazy Loading: Speed Up Initial Render

Don't load everything upfront. Build list items and tabs on demand.

```dart
// ListView.builder: items created only when visible
ListView.builder(
  itemCount: tasks.length,
  itemBuilder: (context, index) => TaskCard(task: tasks[index]),
)

// AutomaticKeepAliveClientMixin: preserve tab state after switching
class _TaskTabPageState extends State<TaskTabPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TaskList();
  }
}

// Network images — show progress while loading
Image.network(
  imageUrl,
  loadingBuilder: (context, child, progress) {
    if (progress == null) return child;
    return const CircularProgressIndicator();
  },
)
```

## 3. Image Caching: cached_network_image

```dart
// pubspec.yaml: cached_network_image: ^3.3.0

CachedNetworkImage(
  imageUrl: 'https://example.com/avatar.jpg',
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  memCacheWidth: 200,    // resize to display size in memory
  memCacheHeight: 200,
  // disk cache survives app restarts
)
```

**Server-side resize with Supabase Storage transforms**:

```dart
final optimizedUrl = supabase.storage
    .from('avatars')
    .getPublicUrl('user123.jpg',
        transform: const TransformOptions(width: 200, height: 200));
```

## Profiling with Flutter DevTools

```bash
flutter run --profile
# Open http://127.0.0.1:9100 in browser
```

Key views:
- **Frame chart**: frames exceeding 16ms (60 fps threshold)
- **Widget rebuild**: red highlights mark excessive rebuilds
- **Memory**: a rising-right graph signals a leak

## Summary

```
const          → attach to static widgets; rebuild skipped for free
Lazy loading   → ListView.builder + AutomaticKeepAlive for fast scroll
Image cache    → cached_network_image + Supabase transforms for right-sized images
Measure first  → DevTools Frame chart to find the bottleneck before optimizing
```

Performance work without measurement is guesswork. Find the slow frame first,
then fix exactly that.
