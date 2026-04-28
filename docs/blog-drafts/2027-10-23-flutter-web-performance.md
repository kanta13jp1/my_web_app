---
title: "Flutter Web パフォーマンス最適化 — Deferred Loading / Tree Shaking / WASM"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter Web パフォーマンス最適化 — Deferred Loading / Tree Shaking / WASM

Flutter Web のビルドサイズと初期ロード時間を削減する3つの手法を実装例付きで解説する。

## なぜ Flutter Web は重いのか

```
デフォルトビルド (flutter build web):
  main.dart.js: 2-5MB (未最適化)
  CanvasKit:    3MB (WebGL レンダラー)
  合計:         5-8MB

→ 3G 回線で初回ロード 10秒超
→ Core Web Vitals (LCP) 悪化 → SEO ペナルティ
```

## Deferred Loading (遅延ロード)

使われないコードを後から読み込む。

```dart
// ❌ NG: 全ページを初回ロード時に読み込む
import 'package:my_app/pages/admin_analytics_page.dart';
import 'package:my_app/pages/horse_racing_page.dart';
import 'package:my_app/pages/ai_university_page.dart';

// ✅ OK: deferred import で分割
import 'package:my_app/pages/admin_analytics_page.dart' deferred as admin;
import 'package:my_app/pages/horse_racing_page.dart' deferred as racing;
import 'package:my_app/pages/ai_university_page.dart' deferred as university;

// 使う直前に loadLibrary()
Future<void> _navigateToAdmin() async {
  await admin.loadLibrary();  // このタイミングで JS チャンクをダウンロード
  if (mounted) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => admin.AdminAnalyticsPage(),
    ));
  }
}
```

**GoRouter との組み合わせ**:

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

## Tree Shaking (未使用コード除去)

```bash
# リリースビルドで自動適用
flutter build web --release

# dart2js が未使用コードを除去
# Material Icons は特に効果大 (全アイコン = 1MB)
```

**必要なアイコンだけ使う**:

```dart
// pubspec.yaml
flutter:
  fonts:
    - family: MaterialIcons
      fonts:
        - asset: fonts/MaterialIcons-Regular.otf
  uses-material-design: true

# ビルド時に使われているアイコンのみバンドル
# 未使用 Icon() = tree shaking で除去 → 数百KB 削減
```

**画像の最適化**:

```dart
// ❌ NG: 全解像度画像を常時ロード
Image.asset('assets/hero_image.png')  // 5MB

// ✅ OK: Web 向け最適化
Image.network(
  'https://storage.googleapis.com/bucket/hero_image_1920w.webp',
  width: 800,
  cacheWidth: 800,  // Flutter が適切なサイズにリサイズ
)
```

## WASM (WebAssembly) ビルド

Flutter 3.22+ で GA。CanvasKit の代わりに WASM を使う。

```bash
# WASM ビルド (Flutter 3.22+)
flutter build web --wasm

# 通常ビルドとの比較:
# JS ビルド:   main.dart.js 4.2MB / 初期ロード 3.2s
# WASM ビルド: app.wasm    2.8MB / 初期ロード 1.9s (40%高速)
```

**注意点**:

```
WASM の制約:
  - Chrome/Edge のみ対応 (2024時点)
  - Safari は近日対応予定
  - Firefox は origin trial 中

→ 対策: dartdevc fallback を維持
flutter build web --wasm --dart-define=FLUTTER_WEB_USE_SKIA=true
```

## SkiaShader の最適化

```dart
// flutter_web_plugins でシェーダーをプリコンパイル
// pubspec.yaml
dependencies:
  flutter_web_plugins:
    sdk: flutter

# flutter_shaders.json でシェーダーをバンドル
# 初回レンダリング時のジャンクを防ぐ
```

## 計測: Lighthouse で Core Web Vitals

```bash
# ローカルで Lighthouse 実行
npx lighthouse http://localhost:5000 \
  --output html \
  --output-path ./lighthouse-report.html

# 目標値:
# LCP (最大コンテンツ描画):  < 2.5s ✅
# FID (初回入力遅延):         < 100ms ✅
# CLS (レイアウトシフト):     < 0.1 ✅
```

## まとめ

```
初回ロード最小化  → Deferred Loading (ルート単位で分割)
バンドルサイズ削減 → Tree Shaking (--release ビルド)
実行速度向上      → WASM (Flutter 3.22+ / Chrome限定)
レンダリング改善  → SkiaShader プリコンパイル
計測             → Lighthouse Core Web Vitals
```

Flutter Web の最適化は「Deferred Loading から始めて、Tree Shaking で削り、WASM で仕上げる」の順が最もリターンが大きい。

