---
title: "Flutter Web Performance: Real Measurements, Real Fixes"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Web Performance: Real Measurements, Real Fixes

Flutter Web's initial load is slow by default. Without the right optimizations, you'll have high bounce rates. Here's what I measured and fixed in a production app.

## Start with Measurement

```bash
# Chrome DevTools Lighthouse on production URL
# (local measurements are inaccurate)
LCP: 4.2s → before
FID: 180ms
CLS: 0.12
```

Measure before you fix. Otherwise you won't know what actually worked.

## 1. CanvasKit → HTML Renderer Switch

Flutter Web has two renderers:

```yaml
--web-renderer canvaskit  # high fidelity, large initial DL (~2.5MB)
--web-renderer html       # lightweight, small initial DL (~300KB)
--web-renderer auto       # mobile=html / desktop=canvaskit
```

**Result**: switching to `--web-renderer html` cut initial load by 1.5s.

```bash
flutter build web --web-renderer html --release
```

Caveat: `html` renderer restricts some CanvasKit-dependent APIs (BlendMode, etc.). Check your widgets first.

## 2. Lazy Loading — Deferred Routing

Don't import every page at the top level:

```dart
// Bad: all pages imported at startup
import 'pages/heavy_page.dart';

// Good: loaded only when the route is navigated to
GoRoute(
  path: '/heavy',
  builder: (context, state) {
    return const HeavyPage();
  },
),
```

Keep heavy widgets (maps, charts, video) out of routes needed on first load.

## 3. Offload Heavy Work with compute()

```dart
// Bad: blocks the UI thread
List<HorseData> heavyParsing(String jsonString) {
  return (jsonDecode(jsonString) as List)
      .map((e) => HorseData.fromJson(e))
      .toList();
}

// Good: runs in an Isolate
final result = await compute(heavyParsing, jsonString);
```

If JSON parsing takes more than 50ms, use `compute()`. The UI stays responsive.

## 4. Image Optimization

```dart
// Bad: raw network image, no caching
Image.network('https://example.com/large.png')

// Good: cached + size constraints
CachedNetworkImage(
  imageUrl: 'https://example.com/large.webp',
  width: 300,
  height: 200,
  memCacheWidth: 300,
)
```

WebP conversion: -60% vs PNG. `CachedNetworkImage` eliminates duplicate requests.

## 5. ListView.builder for Virtual Scrolling

```dart
// Bad: builds all items at once
ListView(children: items.map((e) => ItemWidget(e)).toList())

// Good: builds only visible items
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)
```

For 1000-item lists, `ListView.builder` is mandatory. Plain `ListView` freezes.

## 6. const Constructors Prevent Rebuilds

```dart
// Rebuilds every frame
return Column(children: [
  Text('Static Label'),  // rebuilt every time
  DynamicWidget(),
]);

// Static widgets skip rebuild
return Column(children: [
  const Text('Static Label'),  // skipped
  DynamicWidget(),
]);
```

`flutter analyze` warns about missing `const` via `prefer_const_constructors`. Follow it.

## Measured Results

| Fix | LCP improvement |
| --- | --- |
| HTML renderer | -1.5s |
| WebP images | -0.8s |
| Lazy loading | -0.4s |
| ListView.builder | FID -80ms |
| compute() | jank eliminated |

**Before**: LCP 4.2s → **After**: LCP 1.5s

Lighthouse score: 41 → 78

## Summary

Flutter Web performance work follows this order: renderer selection → images → lazy loading → computation cost. Measure first, fix second, measure again.
