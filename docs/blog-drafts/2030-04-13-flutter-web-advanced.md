---
title: "Flutter Web 実践ガイド — SEO・パフォーマンス・PWA を本番レベルで極める"
tags: flutter,個人開発,webdev,AI
published: true
---

# Flutter Web 実践ガイド — SEO・パフォーマンス・PWA を本番レベルで極める

Flutter Web は「ブラウザで動く Flutter」という域を超え、SEO・Core Web Vitals・PWA まで本格的な Web 開発要件を満たせるプラットフォームになりました。本記事では実際の本番アプリで使える高度なテクニックをまとめます。

## レンダリングモード の選択

Flutter Web には 2 つのレンダリングエンジンがあります。

```yaml
# flutter build web --web-renderer canvaskit  (デフォルト)
# flutter build web --web-renderer html         (旧モード)
# flutter build web --wasm                      (WebAssembly / Dart 3.4+)
```

| モード | 描画品質 | 初期ロード | SEO | 推奨用途 |
|---|---|---|---|---|
| CanvasKit | ★★★ | 重い (~2MB) | ❌ | グラフィック重視アプリ |
| HTML | ★★ | 軽い | △ | コンテンツ重視サイト |
| Wasm | ★★★★ | 中程度 | ❌ | 高性能 Web アプリ |

## SEO 対策: Meta Tags と構造化データ

`web/index.html` で動的 meta tags を管理する:

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  
  <!-- OGP / Twitter Card -->
  <meta property="og:title" content="自分株式会社 — ライフマネジメント">
  <meta property="og:description" content="Notion・MoneyForward など21競合を1つに統合">
  <meta property="og:image" content="https://example.com/og-image.png">
  <meta name="twitter:card" content="summary_large_image">
  
  <!-- 構造化データ (JSON-LD) -->
  <script type="application/ld+json">
  {
    "@context": "https://schema.org",
    "@type": "WebApplication",
    "name": "自分株式会社",
    "description": "AIライフマネジメントアプリ",
    "applicationCategory": "ProductivityApplication"
  }
  </script>
</head>
```

Flutter 側から動的に変更するには `web_meta_tags` パッケージまたは `js` パッケージを使います:

```dart
import 'dart:js_interop';

@JS('document.title')
external set documentTitle(String value);

void updatePageTitle(String title) {
  documentTitle = title;
  // meta タグも更新
  final metaOg = document.querySelector('meta[property="og:title"]');
  metaOg?.setAttribute('content', title);
}
```

## Core Web Vitals 最適化

### LCP (Largest Contentful Paint) 改善

```dart
// 画像の遅延読み込み
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
    // Intersection Observer 的なアプローチ
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
        cacheWidth: 800, // メモリ節約
      ),
    );
  }
}
```

### CLS (Cumulative Layout Shift) 防止

```dart
// アスペクト比を固定してレイアウトシフトを防ぐ
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

### FID / INP 改善: Isolate への処理移譲

```dart
import 'package:flutter/foundation.dart';

// 重い計算を UI スレッドからオフロード
Future<List<SearchResult>> searchInBackground(String query) async {
  return compute(_heavySearch, query);
}

List<SearchResult> _heavySearch(String query) {
  // この処理は別 Isolate で実行される
  return largeDataset
      .where((item) => item.matches(query))
      .toList();
}
```

## PWA 設定

### manifest.json の最適化

```json
{
  "name": "自分株式会社",
  "short_name": "自分株式会社",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#f97316",
  "description": "AIライフマネジメントアプリ",
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

### Service Worker でオフライン対応

`web/flutter_service_worker.js` を拡張:

```javascript
// キャッシュ戦略: Stale While Revalidate
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

## URL 戦略と Deep Link

```dart
// go_router でクリーン URL を実現
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
        final providerId = state.pathParameters['providerId']!;
        return AiProviderPage(providerId: providerId);
      },
    ),
  ],
  // Web でハッシュなし URL を使う
  routerNeglect: false,
);

// main.dart
void main() {
  usePathUrlStrategy(); // /#/ → / に変換
  runApp(const MyApp());
}
```

## Firebase Hosting デプロイ設定

```json
// firebase.json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
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

## Lighthouse スコア改善チェックリスト

```
✅ Performance
  - usePathUrlStrategy() 使用
  - build --release でビルド
  - 不要な package を tree-shake
  - 画像を WebP 形式に変換
  - deferred loading で初期バンドル削減

✅ Accessibility
  - Semantics widget で ARIA ラベル付与
  - フォーカス管理 (FocusTraversalGroup)
  - カラーコントラスト比 4.5:1 以上

✅ Best Practices
  - HTTPS 強制
  - CSP ヘッダー設定
  - 不使用の JS 削除

✅ SEO
  - meta description 設定
  - robots.txt 設定
  - sitemap.xml 作成
```

## まとめ

Flutter Web を本番レベルで運用するには、フレームワークの知識だけでなく Web プラットフォーム固有の要件 (SEO・Core Web Vitals・PWA) を深く理解する必要があります。今回紹介した手法を組み合わせることで、Lighthouse 90+ スコアを達成した本番アプリを構築できます。

---

*自分株式会社では Flutter Web + Firebase Hosting で21競合SaaSを統合するアプリを本番運用中。開発の舞台裏を発信中 → [@kanta13jp1](https://x.com/kanta13jp1)*
