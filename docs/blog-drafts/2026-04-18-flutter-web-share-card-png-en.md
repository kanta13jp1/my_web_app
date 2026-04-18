---
title: "Capture a Flutter Widget as PNG and Download It — Web Share Card"
tags: Flutter,Supabase,buildinpublic,webdev,FlutterTips
published: true
---

# Capture a Flutter Widget as PNG and Download It — Web Share Card

I added a shareable card to my AI University feature. One tap generates a PNG showing "X out of Y providers learned" and downloads it to the user's device.

**Core technique**: `RepaintBoundary` → `toImage()` → `base64` → `HTMLAnchorElement`.

## The 5-Line Core

```dart
import 'dart:convert' show base64Encode;
import 'dart:ui' as ui;
import 'package:web/web.dart' as web_api;

Future<void> _captureAndDownload() async {
  final boundary = _shareCardKey.currentContext
      ?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return;

  final image    = await boundary.toImage(pixelRatio: 2.0);  // 2× for Retina
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return;

  final b64 = base64Encode(byteData.buffer.asUint8List());

  final a = web_api.HTMLAnchorElement()
    ..href     = 'data:image/png;base64,$b64'
    ..download = 'share-card.png';
  web_api.document.body?.append(a);
  a.click();
  a.remove();
}
```

Note: `package:web/web.dart` replaces `dart:html` in Flutter 3.19+.

## Mark the Capture Zone with RepaintBoundary

```dart
final _shareCardKey = GlobalKey();

// Wrap only the card widget — not the whole dialog
RepaintBoundary(
  key: _shareCardKey,
  child: _buildShareCard(),  // fixed 360px width card
)
```

## The Card Widget

```dart
Widget _buildShareCard() {
  return Container(
    width: 360,   // fixed — FittedBox only scales the preview, not the capture
    padding: const EdgeInsets.all(24),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1A1A1A), Color(0xFF1E1E1E)],
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🎓', style: TextStyle(fontSize: 32)),
        Text('$count / $total providers learned',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const Text('my-web-app-b67f4.web.app',
            style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 11)),
      ],
    ),
  );
}
```

## Preview in Dialog (Mobile-Safe)

```dart
// FittedBox shrinks display on small screens,
// but RepaintBoundary captures the full 360px widget
FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.topCenter,
  child: RepaintBoundary(
    key: _shareCardKey,
    child: _buildShareCard(),
  ),
),
```

The captured PNG is always 720px wide (360 × pixelRatio 2.0), regardless of screen width.

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| `dart:html` import error | Deprecated in Flutter 3.19+ | Use `package:web/web.dart` |
| Blank capture | Called before layout | Use `WidgetsBinding.addPostFrameCallback` |
| Blurry text | `pixelRatio: 1.0` | Set `pixelRatio: 2.0` or higher |
| iOS Safari no download | `<a download>` not supported | Fallback to `window.open(dataUrl)` |

## Summary

```
RepaintBoundary(key: _key)
  → boundary.toImage(pixelRatio: 2.0)
  → toByteData(format: png)
  → base64Encode(bytes)
  → HTMLAnchorElement + click()
```

Works today on Chrome/Firefox/Edge. The only Flutter Web–specific part is the `HTMLAnchorElement` download trigger — the rest is pure Flutter.

Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #FlutterTips
