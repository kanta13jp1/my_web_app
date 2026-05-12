---
title: "Flutter Web in Production — SEO, Core Web Vitals, and PWA at Scale"
tags: flutter,webdev,pwa,indiedev
published: true
---

# Flutter Web in Production — SEO, Core Web Vitals, and PWA at Scale

Flutter Web has evolved well beyond "Flutter running in a browser." It now meets serious web requirements: SEO, Core Web Vitals, and full PWA support. This post covers production-grade techniques from a real live app.

## Choosing a Rendering Mode

Flutter Web ships with multiple rendering backends.

```yaml
# flutter build web --web-renderer canvaskit  (default)
# flutter build web --web-renderer html         (legacy)
# flutter build web --wasm                      (WebAssembly / Dart 3.4+)
```

| Mode | Render Quality | Initial Load | SEO | Best For |
|---|---|---|---|---|
| CanvasKit | ★★★ | Heavy (~2 MB) | ❌ | Graphics-heavy apps |
| HTML | ★★ | Light | △ | Content-first sites |
| Wasm | ★★★★ | Medium | ❌ | High-performance apps |

## SEO: Meta Tags and Structured Data

Manage dynamic meta tags in `web/index.html`:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  
  <!-- OGP / Twitter Card -->
  <meta property="og:title" content="Jibun K.K. — Life Management">
  <meta property="og:description" content="Replace 21 SaaS tools with one app">
  <meta property="og:image" content="https://example.com/og-image.png">
  <meta name="twitter:card" content="summary_large_image">
  
  <!-- Structured Data (JSON-LD) -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebApplication",
    "name": "Jibun K.K.",
    "description": "AI life-management app",
    "applicationCategory": "ProductivityApplication"
  }
  </script>
</head>
```

Updating from Dart at runtime:

```dart
import 'dart:js_interop';

@JS('document.title')
external set documentTitle(String value);

void updatePageTitle(String title) {
  documentTitle = title;
  document.querySelector('meta[property="og:title"]')
      ?.setAttribute('content', title);
}
```

## Core Web Vitals Optimization

### LCP — Largest Contentful Paint

```dart
class LazyImage extends StatefulWidget {
  const LazyImage({super.key, required this.src, required this.alt});
  final String src;
  final String alt;

  @override
  State<LazyImage> createState() => _LazyImageState();
}

class _LazyImageState extends State<LazyImage> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Image.network(
        widget.src,
        semanticLabel: widget.alt,
        cacheWidth: 800,
      ),
    );
  }
}
```

### CLS — Cumulative Layout Shift Prevention

```dart
class AspectRatioImage extends StatelessWidget {
  const AspectRatioImage({
    super.key,
    required this.src,
    this.aspectRatio = 16 / 9,
  });

  final String src;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Image.network(src, fit: BoxFit.cover),
    );
  }
}
```

### INP — Offloading to Isolates

```dart
import 'package:flutter/foundation.dart';

Future<List<SearchResult>> searchInBackground(String query) async {
  return compute(_heavySearch, query);
}

List<SearchResult> _heavySearch(String query) {
  return largeDataset
      .where((item) => item.matches(query))
      .toList();
}
```

## PWA Configuration

### Optimised manifest.json

```json
{
  "name": "Jibun K.K.",
  "short_name": "Jibun",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#f97316",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ],
  "screenshots": [
    {
      "src": "screenshots/desktop.png",
      "sizes": "1280x720",
      "type": "image/png",
      "form_factor": "wide"
    }
  ]
}
```

### Service Worker — Offline Support

Extend `web/flutter_service_worker.js` with a Stale-While-Revalidate strategy for images:

```javascript
self.addEventListener('fetch', (event) => {
  if (event.request.destination === 'image') {
    event.respondWith(
      caches.open('images-v1').then(async (cache) => {
        const cached = await cache.match(event.request);
        const networkFetch = fetch(event.request).then((response) => {
          cache.put(event.request, response.clone());
          return response;
        });
        return cached || networkFetch;
      })
    );
  }
});
```

## URL Strategy and Deep Links

```dart
final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomePage()),
    GoRoute(
      path: '/tasks/:taskId',
      builder: (context, state) {
        final taskId = state.pathParameters['taskId']!;
        return TaskDetailPage(taskId: taskId);
      },
    ),
    GoRoute(
      path: '/ai-university/:providerId',
      builder: (context, state) {
        return AiProviderPage(
          providerId: state.pathParameters['providerId']!,
        );
      },
    ),
  ],
);

void main() {
  usePathUrlStrategy(); // removes the # from URLs
  runApp(const MyApp());
}
```

## Firebase Hosting Configuration

```json
{
  "hosting": {
    "public": "build/web",
    "rewrites": [{ "source": "**", "destination": "/index.html" }],
    "headers": [
      {
        "source": "**/*.@(js|css|wasm)",
        "headers": [
          { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
        ]
      },
      {
        "source": "index.html",
        "headers": [
          { "key": "Cache-Control", "value": "no-cache" }
        ]
      }
    ]
  }
}
```

## Lighthouse Score Checklist

```
✅ Performance
  - usePathUrlStrategy()
  - --release build
  - Tree-shake unused packages
  - Convert images to WebP
  - Deferred loading for heavy routes

✅ Accessibility
  - Semantics widgets for ARIA labels
  - FocusTraversalGroup for keyboard navigation
  - Colour contrast ratio ≥ 4.5:1

✅ Best Practices
  - HTTPS enforced
  - CSP headers configured

✅ SEO
  - meta description on every route
  - robots.txt + sitemap.xml
```

## Summary

Running Flutter Web in production requires understanding both the framework and web-platform-specific requirements: SEO, Core Web Vitals, and PWA. Combine the techniques here and you'll routinely hit Lighthouse 90+ on a real production app.

---

*Building a life-management app that replaces 21 SaaS tools with Flutter Web + Firebase Hosting. Follow the journey → [@kanta13jp1](https://x.com/kanta13jp1)*
