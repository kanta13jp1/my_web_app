---
title: "Flutter Web Performance: Deferred Loading, Tree Shaking, and WASM"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Web Performance: Deferred Loading, Tree Shaking, and WASM

Three techniques to shrink bundle size and cut initial load time in Flutter Web — with working code.

## Why Flutter Web Is Heavy by Default

```
Default build (flutter build web):
  main.dart.js: 2-5MB (unoptimized)
  CanvasKit:    3MB (WebGL renderer)
  Total:        5-8MB

→ 10+ seconds on 3G
→ Poor LCP → SEO penalty
```

## Deferred Loading (Code Splitting)

Load code only when it's actually needed.

```dart
// ❌ BAD: all pages bundled into the initial load
import 'package:my_app/pages/admin_analytics_page.dart';
import 'package:my_app/pages/horse_racing_page.dart';

// ✅ GOOD: deferred import splits into separate JS chunks
import 'package:my_app/pages/admin_analytics_page.dart' deferred as admin;
import 'package:my_app/pages/horse_racing_page.dart' deferred as racing;

// Download the chunk only when navigating there
Future<void> _navigateToAdmin() async {
  await admin.loadLibrary();
  if (mounted) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => admin.AdminAnalyticsPage(),
    ));
  }
}
```

**With GoRouter**:

```dart
GoRoute(
  path: '/admin',
  builder: (context, state) => FutureBuilder(
    future: admin.loadLibrary(),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return admin.AdminAnalyticsPage();
    },
  ),
),
```

## Tree Shaking (Dead Code Elimination)

```bash
# Automatically applied in release builds
flutter build web --release

# dart2js removes unreferenced code
# Material Icons is the biggest win (~1MB for the full set)
```

**Use only the icons you need**:

```dart
// Tree shaking drops unused Icon() widgets automatically
// Switching from all-icons to used-only: hundreds of KB saved
Icon(Icons.home)   // kept
Icon(Icons.search) // kept
// Icon(Icons.aviation_mode) → removed if not referenced
```

**Image optimization**:

```dart
// ❌ BAD: full-resolution asset in every load
Image.asset('assets/hero_image.png')  // 5MB

// ✅ GOOD: WebP + cacheWidth
Image.network(
  'https://storage.googleapis.com/bucket/hero_image_1920w.webp',
  width: 800,
  cacheWidth: 800,  // Flutter resizes to this width
)
```

## WASM (WebAssembly) Build

GA in Flutter 3.22+. Replaces CanvasKit JS with native WASM.

```bash
flutter build web --wasm

# Comparison:
# JS build:   main.dart.js 4.2MB / initial load 3.2s
# WASM build: app.wasm    2.8MB / initial load 1.9s  (40% faster)
```

**Browser support caveat**:

```
WASM support (2024):
  Chrome/Edge: ✅ full support
  Firefox:     ⚠️ origin trial
  Safari:      ⚠️ coming soon

→ Keep a JS fallback for now:
flutter build web --wasm --dart-define=FLUTTER_WEB_USE_SKIA=true
```

## Measuring: Lighthouse Core Web Vitals

```bash
npx lighthouse http://localhost:5000 \
  --output html \
  --output-path ./lighthouse-report.html

# Targets:
# LCP (Largest Contentful Paint): < 2.5s ✅
# FID (First Input Delay):         < 100ms ✅
# CLS (Cumulative Layout Shift):   < 0.1 ✅
```

## Summary

```
Minimize initial load   → Deferred Loading (per-route splitting)
Shrink bundle size      → Tree Shaking (--release build)
Speed up execution      → WASM (Flutter 3.22+ / Chrome)
Smooth first render     → SkiaShader precompile
Measure                 → Lighthouse Core Web Vitals
```

Optimize in this order: Deferred Loading first (biggest LCP win), Tree Shaking (easiest), WASM last (highest reward, most constraints). Measure before and after each step.

