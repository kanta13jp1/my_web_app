---
title: "Flutter PlatformView Guide — Embedding Native UI in Flutter"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter PlatformView Guide — Embedding Native UI in Flutter

When you need Google Maps, WebView, or a camera preview in Flutter, PlatformView is the answer. Here's how it works and what to watch out for.

## Two Types of PlatformView

| Type | Platform | Use case |
|------|----------|----------|
| `AndroidView` | Android | Native Android widgets |
| `UiKitView` | iOS | Native UIKit views |
| `HtmlElementView` | Web | iframe / DOM elements |

## Android: Register a PlatformViewFactory

```kotlin
// 1. Implement PlatformView
class NativeMapPlatformView(
  context: Context,
  private val messenger: BinaryMessenger,
  params: Map<*, *>?
) : PlatformView {
  private val mapView = MapView(context).apply {
    val zoom = (params?.get("initialZoom") as? Number)?.toFloat() ?: 10f
    setZoomLevel(zoom)
  }
  override fun getView(): View = mapView
  override fun dispose() { mapView.onDestroy() }
}

// 2. Register factory in MainActivity
class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.platformViewsController.registry
      .registerViewFactory(
        "plugins.example.com/native-map",
        object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
          override fun create(context: Context, id: Int, args: Any?): PlatformView =
            NativeMapPlatformView(context, flutterEngine.dartExecutor.binaryMessenger, args as? Map<*, *>)
        }
      )
  }
}
```

## Dart: Use AndroidView / UiKitView

```dart
class NativeMapWidget extends StatelessWidget {
  const NativeMapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const viewType = 'plugins.example.com/native-map';
    const params = {'initialZoom': 12};

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const AndroidView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: params,
          creationParamsCodec: StandardMessageCodec(),
        ),
      TargetPlatform.iOS => const UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: params,
          creationParamsCodec: StandardMessageCodec(),
        ),
      _ => const Placeholder(),
    };
  }
}
```

## Flutter Web: HtmlElementView

```dart
import 'dart:ui_web' as ui;
import 'dart:html' as html;

void registerIframeFactory() {
  ui.platformViewRegistry.registerViewFactory(
    'embeddedIframe',
    (int viewId) => html.IFrameElement()
      ..src = 'https://example.com/embed'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%',
  );
}

// In your widget:
Widget build(BuildContext context) {
  registerIframeFactory(); // idempotent
  return const SizedBox(
    height: 400,
    child: HtmlElementView(viewType: 'embeddedIframe'),
  );
}
```

## Hybrid Composition vs Virtual Display

```dart
// Prefer Hybrid Composition on Android 10+
// It renders native views in their actual position (better performance)
AndroidView(viewType: viewType) // defaults to Hybrid Composition

// Virtual Display (legacy, more compatible but slower)
PlatformViewLink(
  viewType: viewType,
  surfaceFactory: (context, controller) => AndroidViewSurface(
    controller: controller as AndroidViewController,
    gestureRecognizers: const {},
    hitTestBehavior: PlatformViewHitTestBehavior.opaque,
  ),
  onCreatePlatformView: (params) =>
    PlatformViewsService.initExpensiveAndroidView(
      id: params.id,
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
    )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
     ..create(),
)
```

## Performance Rules

```
1. Wrap in RepaintBoundary to isolate GPU layers
2. Avoid animating PlatformViews (heavy texture compositing)
3. One PlatformView per screen max
4. Prefer existing packages (google_maps_flutter, webview_flutter)
   over manual PlatformView when available
```

## When NOT to Use PlatformView

If you can implement the UI in pure Flutter, do it. PlatformView adds:
- Build complexity (native code per platform)
- Texture compositing overhead
- Gesture conflict risks
- Accessibility gaps (native/Flutter boundaries)

After switching to PlatformView for our map component, native map responsiveness improved 3× over our custom Flutter canvas implementation.

---

Have you embedded native UI in Flutter? Share your approach in the comments!
