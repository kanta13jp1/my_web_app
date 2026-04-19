---
title: "FlutterWebのdart:ui_webをテストでコンパイルできるようにする — 条件分岐importパターン"
tags: Flutter,FlutterWeb,テスト,個人開発,buildinpublic
published: true
---

# FlutterWebのdart:ui_webをテストでコンパイルできるようにする

## 問題: Dart VM でテストが壊れる

Flutter Web ページで YouTube iframe を埋め込む際、`dart:ui_web` と `package:web` を使う:

```dart
// ❌ これを直接 import するとテストが壊れる
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

// initState 内
ui_web.platformViewRegistry.registerViewFactory(
  'youtube-${v.id}',
  (int viewId) {
    final iframe = web.HTMLIFrameElement()
      ..src = 'https://www.youtube.com/embed/${v.id}'
      ..style.width = '100%';
    return iframe;
  },
);
```

これを `flutter test` すると:

```
Compilation failed for test/main_test.dart:
lib/pages/philosophy_page.dart:1:8:
Error: Dart library 'dart:ui_web' is not available on this platform.
```

Dart VM テストランナー (flutter test のデフォルト) は `dart:ui_web` を持たない。
`--platform chrome` にすれば通るが、CI が重くなる。

## 解法: 条件分岐 export で stub を差し込む

3ファイルで解決する:

```
lib/utils/
  platform_view.dart        ← export 切り替え口
  platform_view_stub.dart   ← Dart VM 用 (no-op)
  platform_view_web.dart    ← Flutter Web 用 (本物)
```

```dart
// platform_view.dart — 条件分岐 export
export 'platform_view_stub.dart'
    if (dart.library.ui_web) 'platform_view_web.dart';
```

```dart
// platform_view_stub.dart — Dart VM: no-op
void registerIframeViewFactory(String viewId, String src) {
  // no-op on non-web platforms
}
```

```dart
// platform_view_web.dart — Flutter Web: 本物
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

## 使用側: 直接 import を排除

```dart
// ✅ philosophy_page.dart
import '../utils/platform_view.dart' as platform_view;

// initState 内
for (final v in _videos) {
  platform_view.registerIframeViewFactory(
    'youtube-${v.id}',
    'https://www.youtube.com/embed/${v.id}',
  );
}
```

`dart:ui_web` は `platform_view.dart` の中に閉じ込められた。
`flutter test` は stub を使い、`flutter build web` は本物を使う。

## 確認

```bash
# Dart VM テスト → stub 経由でコンパイル成功
flutter test test/main_test.dart

# Flutter Web ビルド → web 経由で本物使用
flutter build web --release

# flutter analyze 0エラー確認
flutter analyze lib/utils/ lib/pages/philosophy_page.dart
# → No issues found!
```

## まとめ

| | 修正前 | 修正後 |
|--|--------|--------|
| flutter test | ❌ dart:ui_web not available | ✅ stub (no-op) |
| flutter build web | ✅ 動作 | ✅ 本物の実装 |
| flutter analyze | ✅ 0エラー | ✅ 0エラー |

条件分岐 export (`if (dart.library.ui_web)`) を使うと、
プラットフォームに応じて自動で実装が切り替わる。
`dart:html` → `package:web` の移行で同じパターンを多用する。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #FlutterWeb #buildinpublic #個人開発
