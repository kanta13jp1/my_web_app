---
title: "Flutter Web パフォーマンス最適化 — CanvasKit・遅延ロード・画像最適化の実践ガイド"
tags: Flutter,performance,webdev,programming
published: true
---

Flutter Web アプリを本番レベルで運用するには、デフォルト設定のままでは不十分です。本記事では CanvasKit vs HTML レンダラーの選択から始まり、遅延ロード、画像最適化、プロファイリング、ビルド最適化まで、実践的な手法を体系的に解説します。

## 1. CanvasKit vs HTML レンダラー

Flutter Web には 2 つのレンダラーがあります。

| 項目 | CanvasKit | HTML |
|------|-----------|------|
| 描画品質 | 高（Skia ベース） | 中（CSS/SVG） |
| 初回ロードサイズ | ~1.5MB 追加 | 小さい |
| アニメーション | 滑らか | 制限あり |
| テキストレンダリング | 一貫 | OS フォント依存 |
| SEO | 難しい | 容易 |

```bash
# 開発時：レンダラーを指定して起動
flutter run -d chrome --web-renderer canvaskit
flutter run -d chrome --web-renderer html

# ビルド時
flutter build web --web-renderer canvaskit --release
flutter build web --web-renderer html --release

# auto（デスクトップ=CanvasKit, モバイル=HTML）
flutter build web --web-renderer auto --release
```

**推奨戦略**: グラフィック多用アプリは CanvasKit、コンテンツ中心アプリは HTML。
WASM コンパイル（Flutter 3.24+）は CanvasKit をさらに高速化します。

```bash
# WASM ビルド（実験的）
flutter build web --wasm --release
```

## 2. 遅延ロード（Deferred Imports）

Dart の `deferred as` を使うとルート単位でコードを分割できます。

```dart
// main.dart — 重いページを遅延ロード
import 'pages/dashboard_page.dart' deferred as dashboard;
import 'pages/analytics_page.dart' deferred as analytics;
import 'pages/settings_page.dart' deferred as settings;

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/dashboard':
        return MaterialPageRoute(
          builder: (_) => FutureBuilder(
            future: dashboard.loadLibrary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return dashboard.DashboardPage();
              }
              return const _LoadingScreen();
            },
          ),
        );
      case '/analytics':
        return MaterialPageRoute(
          builder: (_) => FutureBuilder(
            future: analytics.loadLibrary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _LoadingScreen();
              }
              return analytics.AnalyticsPage();
            },
          ),
        );
      default:
        return MaterialPageRoute(builder: (_) => const HomePage());
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
```

**プリロード戦略**: ユーザーがホバーしたタイミングでプリロードします。

```dart
// ホバー時にプリロード
class NavItem extends StatelessWidget {
  final String label;
  final Future<void> Function() preload;
  final VoidCallback onTap;

  const NavItem({
    super.key,
    required this.label,
    required this.preload,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => preload(), // ホバー時にバックグラウンドロード
      child: GestureDetector(
        onTap: onTap,
        child: Text(label),
      ),
    );
  }
}
```

## 3. IntersectionObserver による遅延レンダリング

`dart:html` の `IntersectionObserver` でビューポート外のウィジェットをスキップします。

```dart
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

class LazyWidget extends StatefulWidget {
  final Widget child;
  final Widget placeholder;

  const LazyWidget({
    super.key,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
  });

  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  bool _isVisible = false;
  html.IntersectionObserver? _observer;
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupObserver());
  }

  void _setupObserver() {
    // Flutter Web のみ動作
    _observer = html.IntersectionObserver(
      (entries, _) {
        for (final entry in entries) {
          if (entry.isIntersecting && !_isVisible) {
            setState(() => _isVisible = true);
            _observer?.disconnect();
          }
        }
      },
      {'rootMargin': '200px'}, // 200px 手前からプリロード
    );

    final element = _key.currentContext?.findRenderObject();
    if (element != null) {
      // プラットフォームビューの DOM 要素を監視
      // 実際の実装では PlatformViewRegistry を経由
    }
  }

  @override
  void dispose() {
    _observer?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: _isVisible ? widget.child : widget.placeholder,
    );
  }
}
```

## 4. 画像最適化

### ResizeImage でメモリを節約

```dart
// 表示サイズに合わせてデコード解像度を制限
Widget buildOptimizedImage(String url, double displayWidth) {
  return Image(
    image: ResizeImage(
      NetworkImage(url),
      width: (displayWidth * MediaQuery.of(context).devicePixelRatio).toInt(),
      // height は省略すると縦横比を維持
    ),
    fit: BoxFit.cover,
  );
}

// cached_network_image との組み合わせ
import 'package:cached_network_image/cached_network_image.dart';

Widget buildCachedImage(String url) {
  return CachedNetworkImage(
    imageUrl: url,
    memCacheWidth: 800,   // メモリキャッシュの最大幅
    memCacheHeight: 600,
    maxWidthDiskCache: 1200, // ディスクキャッシュの最大幅
    placeholder: (context, url) => const ShimmerPlaceholder(),
    errorWidget: (context, url, error) => const Icon(Icons.error),
    fadeInDuration: const Duration(milliseconds: 200),
  );
}
```

### WebP 対応と srcset 的アプローチ

```dart
// デバイスピクセル比に応じて適切な画像を選択
String getOptimalImageUrl(String baseUrl, BuildContext context) {
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final width = MediaQuery.of(context).size.width;

  if (dpr > 2 || width > 1440) {
    return '$baseUrl?w=1920&format=webp&q=80';
  } else if (dpr > 1 || width > 768) {
    return '$baseUrl?w=960&format=webp&q=80';
  } else {
    return '$baseUrl?w=480&format=webp&q=75';
  }
}

// Supabase Storage の変換 API を活用
String getSupabaseImage(String path, {int width = 800, int quality = 80}) {
  const baseUrl = 'https://<project>.supabase.co/storage/v1/render/image/public';
  return '$baseUrl/$path?width=$width&quality=$quality&format=webp';
}
```

## 5. Performance DevTools でプロファイリング

```bash
# プロファイルモードで起動（release に近い最適化だが DevTools 使用可）
flutter run -d chrome --profile

# ビルドサイズ分析
flutter build web --analyze-size
```

**Timeline でジャンクを検出する手順**:

1. Chrome DevTools → Performance タブ
2. Record ボタンを押してスクロール/アニメーション実行
3. 16ms を超えるフレームを特定
4. Flutter DevTools → Performance → Track Widget Builds

```dart
// 重いビルドを検出するためのデバッグ用計測
class PerformanceOverlayWrapper extends StatelessWidget {
  final Widget child;
  final bool showOverlay;

  const PerformanceOverlayWrapper({
    super.key,
    required this.child,
    this.showOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showOverlay) return child;

    return Stack(
      children: [
        child,
        const PerformanceOverlay.allEnabled(),
      ],
    );
  }
}

// main.dart でフレームコールバックを計測
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // デバッグビルドのみフレーム計測
  assert(() {
    WidgetsBinding.instance.addTimingsCallback((timings) {
      for (final timing in timings) {
        final buildDuration = timing.buildDuration.inMilliseconds;
        if (buildDuration > 8) {
          debugPrint('Slow build: ${buildDuration}ms');
        }
      }
    });
    return true;
  }());

  runApp(const App());
}
```

## 6. ビルド最適化

### Tree Shaking と --split-debug-info

```bash
# デバッグ情報を分離してバイナリを軽量化
flutter build web \
  --release \
  --web-renderer canvaskit \
  --split-debug-info=build/debug-info \
  --obfuscate \
  --dart-define=FLUTTER_WEB_USE_SKIA=true

# ビルドサイズを確認
ls -lh build/web/main.dart.js
```

### 不要なアイコンを除外

```yaml
# pubspec.yaml
flutter:
  uses-material-design: true
  # 使用するアイコンを明示してツリーシェイクを有効化
  # (Flutter 3.17+ でデフォルト有効)
```

```dart
// アイコンを動的に参照すると tree-shaking が無効になる
// NG: 動的参照
IconData getIcon(String name) => IconData(int.parse(name), fontFamily: 'MaterialIcons');

// OK: 静的参照
const icons = {
  'home': Icons.home,
  'settings': Icons.settings,
  'person': Icons.person,
};
```

### Service Worker キャッシュ戦略

```javascript
// web/flutter_service_worker.js をカスタマイズ
// または workbox を使ったカスタム SW

// キャッシュファースト（静的アセット）
workbox.routing.registerRoute(
  ({request}) => request.destination === 'image',
  new workbox.strategies.CacheFirst({
    cacheName: 'images-cache',
    plugins: [
      new workbox.expiration.ExpirationPlugin({
        maxEntries: 100,
        maxAgeSeconds: 30 * 24 * 60 * 60, // 30日
      }),
    ],
  })
);
```

## まとめ

| 最適化項目 | 効果 | 難易度 |
|------------|------|--------|
| レンダラー選択 | 初回ロード 30-50% 改善 | 低 |
| deferred imports | JS バンドル分割 | 中 |
| ResizeImage | メモリ 40-60% 削減 | 低 |
| split-debug-info | バイナリ 20% 削減 | 低 |
| WASM ビルド | CPU バウンド処理 2-3x 高速化 | 中 |

パフォーマンス最適化は計測から始めます。DevTools でボトルネックを特定し、効果の大きい箇所から着手してください。次回は Supabase Realtime を使ったリアルタイム機能の実装を解説します。
