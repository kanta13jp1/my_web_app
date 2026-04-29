---
title: "Flutter Performance Advanced — DevTools Profiling, Skia vs Impeller, and Frame Budget"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter Performance Advanced — DevTools Profiling, Skia vs Impeller, and Frame Budget

When your Flutter app feels sluggish, guessing your way through optimizations wastes time. This article covers scientific profiling with Flutter DevTools and advanced techniques including the Impeller renderer migration.

## Reading the DevTools Timeline Tab

Launch your app with `flutter run --profile`, then open the **Timeline** tab in DevTools. The three key metrics to watch:

- **UI thread**: Dart execution time. Exceeding 16ms causes Jank.
- **Raster thread**: GPU command submission time. Heavy `ShaderMask` or `BackdropFilter` widgets show up here.
- **Frame Budget**: 16.6ms per frame at 60fps, 11.1ms at 90fps.

Click any red-highlighted frame in the timeline to see which widget's `build()` or `paint()` is the bottleneck. Enable `debugProfileBuildsEnabled = true` to overlay rebuild counts directly on the Timeline.

```dart
void main() {
  debugProfileBuildsEnabled = true; // Shows rebuild counts in Timeline
  runApp(const MyApp());
}
```

## Detecting Leaks with the Memory Tab

Enable **Allocation Tracing** in the **Memory** tab, perform a specific user action repeatedly, then compare heap snapshots. If `List<Uint8List>` or `StreamSubscription` objects are accumulating, you have a leak.

Always cancel subscriptions in `dispose()`:

```dart
class _MyState extends State<MyWidget> {
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = stream.listen(_onData);
  }

  @override
  void dispose() {
    _sub.cancel(); // Without this, Memory tab shows accumulation
    super.dispose();
  }
}
```

## Skia vs Impeller — What's the Difference?

Flutter's rendering backend was historically **Skia**, but since Flutter 3.10, **Impeller** is the default on iOS and is rolling out to Android.

| Aspect | Skia | Impeller |
|--------|------|----------|
| Shader compilation | Runtime (= first-run Jank) | Pre-compiled (= no Jank) |
| Metal / Vulkan | Via abstraction layer | Native |
| Custom shaders | Limited support | GLSL subset supported |

The biggest win with Impeller is eliminating shader-compilation Jank — the stutter users see the very first time they trigger an animation.

**Enable Impeller on Android** (opt-in):

```yaml
# Inside <application> in AndroidManifest.xml
<meta-data
  android:name="io.flutter.embedding.android.EnableImpeller"
  android:value="true" />
```

If you encounter rendering artifacts, disable it temporarily with `--no-enable-impeller` and file a GitHub issue.

## Leveraging const Constructors Aggressively

Adding `const` to a widget prevents Flutter from rebuilding it when its parent rebuilds. Make every widget that can be a compile-time constant into one.

```dart
// Rebuilds every time parent rebuilds
Column(children: [Text('Hello'), Icon(Icons.star)]);

// Never rebuilds — zero rebuild cost
const Column(children: [Text('Hello'), Icon(Icons.star)]);
```

Add the `prefer_const_constructors` lint rule to your `analysis_options.yaml` so the analyzer flags every missed opportunity automatically.

## RepaintBoundary and IndexedStack

Wrap animated widgets in `RepaintBoundary` to isolate their repaint region. Only the bounded layer gets re-rasterized, saving the parent from unnecessary GPU work.

```dart
RepaintBoundary(
  child: AnimatedProgressRing(value: _progress),
)
```

`IndexedStack` keeps off-screen tab content alive in memory, eliminating rebuild cost on tab switch. Use it when tabs hold expensive state — but be aware memory usage grows proportionally.

## Freeing the Main Thread with Dart Isolates

CPU-bound work like JSON decoding and image processing should always run in a separate Isolate. The simplest API is `compute()`:

```dart
Future<List<Item>> parseItems(String jsonStr) async {
  // Runs in a background isolate — main thread stays responsive
  return compute(_decodeItems, jsonStr);
}

List<Item> _decodeItems(String jsonStr) {
  final list = jsonDecode(jsonStr) as List;
  return list.map((e) => Item.fromJson(e)).toList();
}
```

For bidirectional, long-lived communication, use `Isolate.spawn()` directly with `SendPort`/`ReceivePort`. When transferring large typed buffers (e.g., decoded image pixels), wrap them in `TransferableTypedData` for zero-copy transfer between isolates.

```dart
final transferable = TransferableTypedData.fromList([pixelBuffer]);
sendPort.send(transferable);
// Receiver side:
final data = (message as TransferableTypedData).materialize();
```

## Summary

1. Use the **Timeline** tab to pinpoint Jank frames and check rebuild counts.
2. Use the **Memory** tab to catch `StreamSubscription` and image cache leaks.
3. Impeller eliminates first-run shader Jank — test it on both iOS and Android.
4. `const` constructors + `RepaintBoundary` + `compute()` are the three pillars of advanced Flutter performance.

Measure first, optimize second. DevTools gives you the data — use it before touching a single line of code. Next up: advanced Supabase Edge Functions patterns.
