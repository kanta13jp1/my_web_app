---
title: "Making dart:ui_web Compile in Flutter Tests — The Conditional Import Pattern"
tags: Flutter,FlutterWeb,testing,buildinpublic,webdev
published: false
---

# Making dart:ui_web Compile in Flutter Tests

## The Problem

When embedding YouTube iframes in Flutter Web, you use `dart:ui_web` and `package:web`:

```dart
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

// in initState
ui_web.platformViewRegistry.registerViewFactory(
  'youtube-$id',
  (int viewId) {
    final iframe = web.HTMLIFrameElement()..src = embedUrl;
    return iframe;
  },
);
```

Works on Flutter Web. Breaks in tests:

```
Compilation failed for test/main_test.dart:
lib/pages/philosophy_page.dart:1:8:
Error: Dart library 'dart:ui_web' is not available on this platform.
```

`flutter test` defaults to Dart VM, which doesn't have `dart:ui_web`. Running with `--platform chrome` fixes it but slows CI significantly.

## The Fix: Conditional Export

Three files:

```
lib/utils/
  platform_view.dart        ← conditional export switch
  platform_view_stub.dart   ← Dart VM (no-op)
  platform_view_web.dart    ← Flutter Web (real impl)
```

```dart
// platform_view.dart
export 'platform_view_stub.dart'
    if (dart.library.ui_web) 'platform_view_web.dart';
```

```dart
// platform_view_stub.dart
void registerIframeViewFactory(String viewId, String src) {
  // no-op — Dart VM can't render iframes anyway
}
```

```dart
// platform_view_web.dart
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

void registerIframeViewFactory(String viewId, String src) {
  ui_web.platformViewRegistry.registerViewFactory(
    viewId,
    (int viewIdInt) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..allow = 'accelerometer; autoplay; clipboard-write; '
            'encrypted-media; gyroscope; picture-in-picture'
        ..setAttribute('allowfullscreen', 'true')
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    },
  );
}
```

## Usage: Drop the Direct Import

```dart
// philosophy_page.dart — before
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

// after
import '../utils/platform_view.dart' as platform_view;

// initState — same call site, different impl behind it
for (final v in _videos) {
  platform_view.registerIframeViewFactory(
    'youtube-${v.id}',
    'https://www.youtube.com/embed/${v.id}',
  );
}
```

## How the Conditional Export Works

`if (dart.library.ui_web)` is evaluated at compile time:
- Dart VM: `dart.library.ui_web` is absent → `platform_view_stub.dart` is used
- Flutter Web: `dart.library.ui_web` is present → `platform_view_web.dart` is used

No `kIsWeb` check needed at runtime. The right file is compiled in.

## Result

| | Before | After |
|--|--------|-------|
| `flutter test` | ❌ dart:ui_web compile error | ✅ stub compiles |
| `flutter build web` | ✅ works | ✅ works (real impl) |
| `flutter analyze` | ✅ 0 errors | ✅ 0 errors |
| CI (Dart VM tests) | ❌ 13 tests fail | ✅ all pass |

The pattern applies to any `dart:html`/`dart:ui_web`/`package:web` usage in pages that are also covered by tests. The `dart.library.*` condition is the standard Flutter approach for platform-conditional imports.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #FlutterWeb #buildinpublic #testing
