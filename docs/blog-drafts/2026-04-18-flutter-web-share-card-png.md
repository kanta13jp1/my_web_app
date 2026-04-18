---
title: "Flutter Web でウィジェットをPNG画像化してダウンロードする — SNSシェアカード実装"
tags: Flutter,Supabase,buildinpublic,AI,個人開発
published: true
---

# Flutter Web でウィジェットをPNG画像化してダウンロードする — SNSシェアカード実装

## はじめに

自分株式会社 AI大学に「SNSシェアカード」機能を実装しました。「何社学習済み」かを OGPスタイルのカード画像に変換し、ワンタップでダウンロード → SNS投稿できます。

**技術の核心**: `RepaintBoundary` → `toImage()` → `base64` → `HTMLAnchorElement` の4ステップで Flutter Web ウィジェットを PNG として保存します。

## 実装コード

### Step 1: RepaintBoundary でキャプチャ範囲を指定

```dart
final _shareCardKey = GlobalKey();

// ダイアログ内でカードを RepaintBoundary でラップ
RepaintBoundary(
  key: _shareCardKey,
  child: _buildShareCard(),  // 360px 固定幅のカードウィジェット
)
```

### Step 2: PNG キャプチャ → base64 → ダウンロード

```dart
import 'dart:convert' show base64Encode;
import 'dart:ui' as ui;
import 'package:web/web.dart' as web_api;

Future<void> _captureAndDownload() async {
  final boundary = _shareCardKey.currentContext
      ?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;

  // pixelRatio: 2.0 で Retina 相当の解像度
  final image    = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;

  final b64 = base64Encode(byteData.buffer.asUint8List());

  // HTMLAnchorElement でブラウザダウンロードをトリガー
  final a = web_api.HTMLAnchorElement()
    ..href     = 'data:image/png;base64,$b64'
    ..download = 'ai-university-card.png';
  web_api.document.body?.append(a);
  a.click();
  a.remove();
}
```

`package:web/web.dart` は Flutter 3.19+ での `dart:html` 代替です。

### Step 3: シェアカードウィジェット

```dart
Widget _buildShareCard() {
  return Container(
    width: 360,  // 固定幅 (FittedBox がモバイル表示で縮小)
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A1A1A), Color(0xFF1E1E1E)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('🎓', style: TextStyle(fontSize: 32)),
        Text('$count / $total 社学習済み',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        // ... ストリーク・バッジ数も表示
        const Text('my-web-app-b67f4.web.app',
            style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 11)),
      ],
    ),
  );
}
```

### Step 4: ダイアログ内でのプレビュー

```dart
// モバイル幅でもカードが収まるよう FittedBox でスケールダウン
FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.topCenter,
  child: RepaintBoundary(
    key: _shareCardKey,
    child: _buildShareCard(),
  ),
),
```

キャプチャ対象は固定幅 360px のまま。FittedBox は **表示のみ** 縮小するため、PNG は常に 720px (pixelRatio: 2.0 × 360px) で生成されます。

## 注意点

| 問題 | 原因 | 対処 |
|------|------|------|
| `dart:html` import error | Flutter 3.19+ で非推奨 | `package:web/web.dart` を使う |
| キャプチャが空白 | ビルドが完了する前に呼んだ | `WidgetsBinding.addPostFrameCallback` で遅延 |
| 高 DPI で文字がぼける | pixelRatio: 1.0 | `pixelRatio: 2.0` 以上に設定 |
| iOS Safari でダウンロード不可 | `<a download>` 非対応 | `window.open(data:URL)` でフォールバック |

## まとめ

```
RepaintBoundary (key)
  → boundary.toImage(pixelRatio: 2.0)
  → image.toByteData(format: png)
  → base64Encode
  → HTMLAnchorElement + click()
```

この5行でFlutter WebウィジェットをPNG保存できます。`package:web/web.dart` への移行さえ済んでいれば、あとはほぼコピペで動きます。

無料で体験できます: https://my-web-app-b67f4.web.app/

---
#FlutterWeb #Supabase #buildinpublic #個人開発 #FlutterTips
