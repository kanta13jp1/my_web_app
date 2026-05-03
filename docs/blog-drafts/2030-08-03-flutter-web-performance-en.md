---
title: "Flutter Web Performance Optimization — CanvasKit, Lazy Loading, and Image Best Practices"
tags: flutter,performance,webdev,programming
published: true
---

Shipping a production-ready Flutter Web app requires going beyond default settings. This guide covers renderer selection, deferred imports, image optimization, profiling, and build-time optimizations — all with practical code examples.

## 1. CanvasKit vs HTML Renderer

Flutter Web ships two renderers. Picking the right one is the highest-leverage decision you can make.

| Aspect | CanvasKit | HTML |
|--------|-----------|------|
| Rendering quality | High (Skia) | Medium (CSS/SVG) |
| Initial bundle size | +~1.5 MB | Smaller |
| Animation smoothness | Excellent | Limited |
| Text rendering | Consistent | OS font dependent |
| SEO friendliness | Hard | Easier |

```bash
# Development — specify renderer
flutter run -d chrome --web-renderer canvaskit
flutter run -d chrome --web-renderer html

# Production builds
flutter build web --web-renderer canvaskit --release
flutter build web --web-renderer html --release

# auto: CanvasKit on desktop, HTML on mobile
flutter build web --web-renderer auto --release

# WASM compilation (Flutter 3.24+, experimental)
flutter build web --wasm --release
```

**Rule of thumb**: graphics-heavy apps → CanvasKit; content-heavy apps → HTML renderer. WASM compilation can further accelerate CanvasKit for CPU-bound workloads by 2–3×.

## 2. Deferred Imports for Code Splitting

Dart's `deferred as` keyword enables route-level code splitting, keeping the initial JS bundle minimal.

```dart
// main.dart — defer heavy pages
import 'pages/dashboard_page.dart' deferred as dashboard;
import 'pages/analytics_page.dart' deferred as analytics;
import 'pages/settings_page.dart' deferred as settings;

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/dashboard':
        return MaterialPageRoute(
          builder: (_) => FutureBuilder<void>(
            future: dashboard.loadLibrary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return dashboard.DashboardPage();
              }
              return const LoadingScreen();
            },
          ),
        );

      case '/analytics':
        return MaterialPageRoute(
          builder: (_) => FutureBuilder<void>(
            future: analytics.loadLibrary(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LoadingScreen();
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
```

**Preload on hover** — load the next page before the user clicks:

```dart
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
      onEnter: (_) => preload(), // background load on hover
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(label),
        ),
      ),
    );
  }
}

// Usage
NavItem(
  label: 'Dashboard',
  preload: dashboard.loadLibrary,
  onTap: () => context.go('/dashboard'),
)
```

## 3. Lazy Rendering with IntersectionObserver

Use the browser's `IntersectionObserver` API to avoid building widgets that are off-screen.

```dart
import 'dart:html' as html;
import 'package:flutter/widgets.dart';

/// Renders [child] only once it enters the viewport.
/// Shows [placeholder] until then.
class LazyWidget extends StatefulWidget {
  final Widget child;
  final Widget placeholder;
  /// Preload distance in pixels above the fold
  final int rootMarginPx;

  const LazyWidget({
    super.key,
    required this.child,
    this.placeholder = const SizedBox.shrink(),
    this.rootMarginPx = 200,
  });

  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  bool _visible = false;
  html.IntersectionObserver? _observer;

  @override
  void initState() {
    super.initState();
    _observer = html.IntersectionObserver(
      (entries, _) {
        if (entries.any((e) => e.isIntersecting)) {
          setState(() => _visible = true);
          _observer?.disconnect();
        }
      },
      {'rootMargin': '${widget.rootMarginPx}px'},
    );
    // Attach after the first frame so the DOM element exists
    WidgetsBinding.instance.addPostFrameCallback((_) => _attach());
  }

  void _attach() {
    // Real implementation uses PlatformViewRegistry to get the DOM node
    // This pattern works with HtmlElementView or flutter_web_plugins
  }

  @override
  void dispose() {
    _observer?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _visible ? widget.child : widget.placeholder;
}
```

## 4. Image Optimization

### ResizeImage — Decode at Display Resolution

```dart
/// Constrain decode resolution to the actual display size,
/// saving significant heap memory on mobile and high-DPI screens.
Widget optimizedNetworkImage(
  BuildContext context,
  String url, {
  double? displayWidth,
  double? displayHeight,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  return Image(
    image: ResizeImage(
      NetworkImage(url),
      width: displayWidth != null ? (displayWidth * dpr).round() : null,
      height: displayHeight != null ? (displayHeight * dpr).round() : null,
    ),
    fit: BoxFit.cover,
  );
}
```

### CachedNetworkImage with Memory + Disk Limits

```dart
import 'package:cached_network_image/cached_network_image.dart';

Widget cachedImage(String url) {
  return CachedNetworkImage(
    imageUrl: url,
    memCacheWidth: 800,       // px — limits decoded size in memory
    memCacheHeight: 600,
    maxWidthDiskCache: 1200,  // px — limits size written to disk
    fadeInDuration: const Duration(milliseconds: 200),
    placeholder: (_, __) => const ShimmerBox(),
    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
  );
}
```

### Supabase Storage Image Transforms

```dart
/// Use Supabase's built-in image transformation API.
/// Automatically serves WebP when the browser supports it.
String supabaseImageUrl(
  String bucket,
  String path, {
  int width = 800,
  int quality = 80,
}) {
  const projectRef = 'YOUR_PROJECT_REF';
  return 'https://$projectRef.supabase.co'
      '/storage/v1/render/image/public/$bucket/$path'
      '?width=$width&quality=$quality&format=webp';
}

// Usage — responsive image for a card
Widget productCard(String imagePath) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final url = supabaseImageUrl(
        'products',
        imagePath,
        width: constraints.maxWidth.round(),
      );
      return CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
    },
  );
}
```

## 5. Profiling with Flutter DevTools

```bash
# Run in profile mode — release optimizations, DevTools still works
flutter run -d chrome --profile

# Measure output bundle size
flutter build web --analyze-size --release
```

**Finding jank in the Timeline**:

```dart
// Instrument slow sections manually
import 'dart:developer' as developer;

Future<void> loadDashboardData() async {
  developer.Timeline.startSync('LoadDashboardData');
  try {
    final results = await Future.wait([
      _fetchMetrics(),
      _fetchNotifications(),
      _fetchRecentActivity(),
    ]);
    // process results...
  } finally {
    developer.Timeline.finishSync();
  }
}
```

**Frame timing callback** (debug builds only):

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  assert(() {
    WidgetsBinding.instance.addTimingsCallback((timings) {
      for (final t in timings) {
        final ms = t.totalSpan.inMilliseconds;
        if (ms > 16) debugPrint('Slow frame: ${ms}ms (build: ${t.buildDuration.inMilliseconds}ms)');
      }
    });
    return true;
  }());

  runApp(const App());
}
```

## 6. Build-time Optimizations

### split-debug-info + obfuscate

```bash
flutter build web \
  --release \
  --web-renderer canvaskit \
  --split-debug-info=build/symbols \
  --obfuscate \
  --dart-define=FLUTTER_WEB_USE_SKIA=true

# Check output size
ls -lh build/web/main.dart.js
# Typical: 2–3 MB (CanvasKit), 1–1.5 MB (HTML renderer)
```

### Avoid Breaking Tree-Shaking

```dart
// Bad — dynamic icon lookup defeats tree-shaking
IconData iconFromCode(int codePoint) =>
    IconData(codePoint, fontFamily: 'MaterialIcons');

// Good — static map keeps icons tree-shakeable
const _iconMap = {
  'home': Icons.home,
  'person': Icons.person,
  'settings': Icons.settings,
};
IconData? iconFor(String key) => _iconMap[key];
```

### Service Worker Cache Strategy

```javascript
// Customize web/flutter_service_worker.js or use Workbox

// Cache-first for images (long TTL)
workbox.routing.registerRoute(
  ({ request }) => request.destination === 'image',
  new workbox.strategies.CacheFirst({
    cacheName: 'images-v1',
    plugins: [
      new workbox.expiration.ExpirationPlugin({
        maxEntries: 150,
        maxAgeSeconds: 30 * 24 * 60 * 60, // 30 days
      }),
    ],
  })
);

// Network-first for API calls (freshness matters)
workbox.routing.registerRoute(
  ({ url }) => url.pathname.startsWith('/api/'),
  new workbox.strategies.NetworkFirst({ cacheName: 'api-cache' })
);
```

## Summary

| Optimization | Impact | Effort |
|-------------|--------|--------|
| Renderer selection | 30–50% faster initial load | Low |
| Deferred imports | Smaller initial JS bundle | Medium |
| ResizeImage | 40–60% less heap memory | Low |
| split-debug-info | ~20% smaller binary | Low |
| WASM build | 2–3× faster CPU-bound code | Medium |

Always measure before optimizing. Use DevTools to find real bottlenecks — then apply targeted fixes. Next week we look at Supabase Realtime for live collaborative features.
