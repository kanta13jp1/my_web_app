---
title: "Flutter Web Rendering Complete Guide — CanvasKit vs HTML Renderer"
tags: flutter,dart,webdev,indiedev
published: true
---

# Flutter Web Rendering Complete Guide — CanvasKit vs HTML Renderer

Flutter Web supports two renderers. Understanding CanvasKit vs HTML renderer helps you pick the right one for your app.

## Two Renderers

### HTML Renderer
- **How it works**: HTML / CSS / Canvas 2D API
- **Bundle size**: Small (~1MB)
- **Initial load**: Fast
- **Fidelity**: May differ slightly from Flutter desktop
- **Best for**: Text-heavy, document-style apps

### CanvasKit Renderer
- **How it works**: Skia compiled to WebAssembly
- **Bundle size**: Large (~4MB with Skia WASM)
- **Initial load**: Slower (WASM download required)
- **Fidelity**: Pixel-perfect match with native
- **Best for**: Graphics-heavy apps, games, custom drawing

## Switching Renderers

```bash
# Build with HTML renderer
flutter build web --web-renderer html

# Build with CanvasKit
flutter build web --web-renderer canvaskit

# Auto (default): mobile → HTML / desktop → CanvasKit
flutter build web --web-renderer auto

# Dev server
flutter run -d chrome --web-renderer canvaskit
```

## Checking the Active Renderer

```dart
import 'package:flutter/foundation.dart';

void checkRenderer() {
  if (kIsWeb) {
    debugPrint('Renderer: ${RendererBinding.instance.rendererType}');
  }
}
```

## Custom Painting

```dart
class ChartPainter extends CustomPainter {
  final List<double> data;
  ChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height * (1 - data[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, paint);

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = const Color(0xFF4F46E5).withOpacity(0.1)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(ChartPainter old) => old.data != data;
}
```

## Web-Specific Optimizations

```dart
import 'package:flutter/foundation.dart';

class WebOptimizedImage extends StatelessWidget {
  final String url;
  const WebOptimizedImage(this.url);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Image.network(
        url,
        cacheWidth: 800,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const CircularProgressIndicator();
        },
      );
    }
    return CachedNetworkImage(imageUrl: url);
  }
}
```

## SEO with HTML Renderer

```dart
import 'package:url_strategy/url_strategy.dart';

void main() {
  setPathUrlStrategy(); // Remove hash (#) from URLs
  runApp(const App());
}
```

```html
<!-- web/index.html -->
<meta name="description" content="AI Life Management App">
<meta property="og:title" content="Jibun AI">
<link rel="canonical" href="https://my-web-app-b67f4.web.app/">
```

## PWA Configuration

```json
{
  "name": "Jibun AI",
  "short_name": "Jibun AI",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#1e1b4b",
  "theme_color": "#4f46e5",
  "icons": [
    {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
    {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"}
  ]
}
```

## Comparison Table

| | HTML renderer | CanvasKit |
| --- | --- | --- |
| Bundle size | ~1MB | ~4MB |
| Initial load | Fast | Slower |
| Fidelity | Approximate | Pixel-perfect |
| SEO | Good | Needs work |
| Best for | Docs / LP | Graphics / Games |

Start with Auto mode and switch based on your specific requirements.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
