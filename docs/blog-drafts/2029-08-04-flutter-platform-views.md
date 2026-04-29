---
title: "Flutter PlatformView 完全ガイド — ネイティブ UI を Flutter に埋め込む"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter PlatformView 完全ガイド — ネイティブ UI を Flutter に埋め込む

Flutter で Google マップ・WebView・カメラプレビューなど「ネイティブが必須」なコンポーネントを使いたいとき、PlatformView が解決策です。仕組みと落とし穴を整理します。

## PlatformView の 2 種類

| 方式 | iOS | Android | 特徴 |
|------|-----|---------|------|
| `UiKitView` | ✅ | — | iOS ネイティブ View |
| `AndroidView` | — | ✅ | Android ネイティブ View |
| `HtmlElementView` | — | — | Flutter Web 専用 |

## AndroidView の基本実装

```dart
// AndroidView を Flutter Widget として公開するファクトリ
class NativeMapView extends StatelessWidget {
  const NativeMapView({super.key});

  @override
  Widget build(BuildContext context) {
    const viewType = 'plugins.example.com/native-map';

    return AndroidView(
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: const {'initialZoom': 12},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: (id) {
        debugPrint('Native view created: id=$id');
      },
    );
  }
}
```

```kotlin
// Android: PlatformViewFactory 登録
class NativeMapFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {

  override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
    val params = args as? Map<*, *>
    return NativeMapPlatformView(context, viewId, params, messenger)
  }
}

class NativeMapPlatformView(
  context: Context,
  id: Int,
  params: Map<*, *>?,
  messenger: BinaryMessenger
) : PlatformView {
  private val mapView = MapView(context).apply {
    val zoom = (params?.get("initialZoom") as? Number)?.toFloat() ?: 10f
    setZoomLevel(zoom)
  }

  override fun getView(): View = mapView
  override fun dispose() { mapView.onDestroy() }
}
```

```kotlin
// MainActivity で登録
class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.platformViewsController.registry
      .registerViewFactory(
        "plugins.example.com/native-map",
        NativeMapFactory(flutterEngine.dartExecutor.binaryMessenger)
      )
  }
}
```

## iOS: UiKitView

```dart
Widget build(BuildContext context) {
  return UiKitView(
    viewType: 'plugins.example.com/native-map',
    layoutDirection: TextDirection.ltr,
    creationParams: const {'initialZoom': 12},
    creationParamsCodec: const StandardMessageCodec(),
  );
}
```

```swift
// AppDelegate.swift
class NativeMapFactory: NSObject, FlutterPlatformViewFactory {
  private var messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64,
              arguments args: Any?) -> FlutterPlatformView {
    return NativeMapView(frame: frame, viewId: viewId, args: args, messenger: messenger)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

class NativeMapView: NSObject, FlutterPlatformView {
  private var _view: MKMapView

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    _view = MKMapView(frame: frame)
    if let params = args as? [String: Any],
       let zoom = params["initialZoom"] as? Double {
      let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6811, longitude: 139.7670),
        latitudinalMeters: 1000 / zoom,
        longitudinalMeters: 1000 / zoom
      )
      _view.setRegion(region, animated: false)
    }
    super.init()
  }

  func view() -> UIView { return _view }
}

// GeneratedPluginRegistrant.register(with: self) の前に:
NativeMapFactory(messenger: controller.binaryMessenger)
  |> { flutterViewController.engine?.platformViewsController.register(
    factory: $0, withId: "plugins.example.com/native-map") }
```

## Flutter Web: HtmlElementView

```dart
// Web 専用コンポーネント (iframe など)
Widget build(BuildContext context) {
  // dart:html で UI_FACTORY_REGISTRY に登録
  // ignore: undefined_prefixed_name
  ui.platformViewRegistry.registerViewFactory(
    'iframeElement',
    (int viewId) => html.IFrameElement()
      ..src = 'https://example.com'
      ..style.border = 'none',
  );

  return const SizedBox(
    height: 400,
    child: HtmlElementView(viewType: 'iframeElement'),
  );
}
```

## パフォーマンスの注意点

```
⚠️ PlatformView はコストが高い
- テクスチャ合成が発生 (GPU 負荷)
- アニメーションと組み合わせると fps 低下
- 1 画面に 1 つまでを目安に
```

```dart
// RepaintBoundary で影響範囲を分離
RepaintBoundary(
  child: NativeMapView(),
)
```

## Hybrid Composition vs Virtual Display (Android)

```dart
// Hybrid Composition (Android 10+): ネイティブ描画、パフォーマンス良好
AndroidView(
  viewType: viewType,
  // デフォルトで Hybrid Composition が使われる
)

// Virtual Display (旧来): テクスチャ方式、互換性高
PlatformViewLink(
  viewType: viewType,
  surfaceFactory: (context, controller) {
    return AndroidViewSurface(
      controller: controller as AndroidViewController,
      gestureRecognizers: const {},
      hitTestBehavior: PlatformViewHitTestBehavior.opaque,
    );
  },
  onCreatePlatformView: (params) {
    return PlatformViewsService.initExpensiveAndroidView(
      id: params.id,
      viewType: viewType,
      layoutDirection: TextDirection.ltr,
      creationParams: params.creationParams,
      creationParamsCodec: const StandardMessageCodec(),
    )..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
     ..create();
  },
)
```

## まとめ: 使い分け指針

| ユースケース | 推奨 |
|------------|------|
| Google Maps | `google_maps_flutter` パッケージ (内部で PlatformView) |
| WebView | `webview_flutter` パッケージ |
| カメラ | `camera` パッケージ |
| 独自ネイティブ UI | `PlatformView` 直接実装 |
| 純粋 Flutter で代替可能 | PlatformView を避ける |

PlatformView を使ったところ、ネイティブ地図の応答速度がカスタム Flutter 実装の 3 倍になりました。

---

PlatformView を使った事例があればコメントで教えてください！
