---
title: "Flutter Web レンダリング完全ガイド — CanvasKit vs HTML renderer の使い分け"
tags: flutter,dart,個人開発,AI
published: true
---

# Flutter Web レンダリング完全ガイド — CanvasKit vs HTML renderer の使い分け

Flutter Web は 2 種類のレンダラーをサポートします。CanvasKit と HTML renderer の違いを理解して、アプリに最適な選択をしましょう。

## 2つのレンダラー

### HTML Renderer
- **仕組み**: HTML / CSS / Canvas 2D API を使用
- **バンドルサイズ**: 小さい (~1MB)
- **初回ロード**: 速い
- **描画精度**: Flutter デスクトップと若干異なる場合あり
- **適用場面**: テキスト主体・ドキュメント型アプリ

### CanvasKit Renderer
- **仕組み**: Skia を WebAssembly にコンパイルして使用
- **バンドルサイズ**: 大きい (~2MB + Skia WASM ~2MB)
- **初回ロード**: 遅め (WASM ダウンロード必要)
- **描画精度**: ネイティブと同一
- **適用場面**: グラフィック重視・ゲーム・カスタム描画

## レンダラー切り替え

```bash
# HTML renderer でビルド
flutter build web --web-renderer html

# CanvasKit でビルド
flutter build web --web-renderer canvaskit

# Auto (デフォルト): モバイルは HTML / デスクトップは CanvasKit
flutter build web --web-renderer auto

# 開発サーバー
flutter run -d chrome --web-renderer canvaskit
```

## パフォーマンス計測

```dart
// web/index.html でレンダラーを確認
import 'package:flutter/foundation.dart';

void checkRenderer() {
  if (kIsWeb) {
    // CanvasKit: 'canvaskit' / HTML: 'html'
    debugPrint('Renderer: ${RendererBinding.instance.rendererType}');
  }
}
```

## カスタム描画 (CustomPainter)

CanvasKit と HTML renderer で描画結果が異なるケースへの対応:

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
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // 塗りつぶし
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

## Web 専用最適化

```dart
// Web のみ適用するコード
import 'package:flutter/foundation.dart';

class WebOptimizedImage extends StatelessWidget {
  final String url;
  const WebOptimizedImage(this.url);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // Web では NetworkImage + cacheWidth でメモリ節約
      return Image.network(
        url,
        cacheWidth: 800,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const CircularProgressIndicator();
        },
      );
    }
    // モバイルは cached_network_image を使用
    return CachedNetworkImage(imageUrl: url);
  }
}
```

## SEO 対応 (HTML renderer 推奨)

```dart
// web/index.html に meta タグを追加
// flutter_web_plugins でルーティング
import 'package:url_strategy/url_strategy.dart';

void main() {
  setPathUrlStrategy(); // ハッシュ (#) を除去
  runApp(const App());
}
```

```html
<!-- web/index.html -->
<meta name="description" content="AIライフマネジメントアプリ — 自分株式会社">
<meta property="og:title" content="自分AI">
<meta property="og:description" content="21競合の機能を1つに統合">
<link rel="canonical" href="https://my-web-app-b67f4.web.app/">
```

## PWA 設定

```json
// web/manifest.json
{
  "name": "自分AI",
  "short_name": "自分AI",
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

## まとめ

| 項目 | HTML renderer | CanvasKit |
| --- | --- | --- |
| バンドルサイズ | ~1MB | ~4MB |
| 初回ロード | 速い | 遅め |
| 描画精度 | 近似 | ネイティブ同一 |
| SEO | 良好 | 要工夫 |
| 推奨シーン | ドキュメント・LP | グラフィック・ゲーム |

Auto モードを基準に、要件に応じて切り替えるのがベストプラクティスです。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
