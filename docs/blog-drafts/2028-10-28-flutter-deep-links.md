---
title: "Flutter ディープリンク — App Links・Universal Links・go_router 連携"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter ディープリンク — App Links・Universal Links・go_router 連携

`myapp://` と `https://` 両方からアプリを開く実装を解説する。

## Android: App Links 設定

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<activity ...>
  <intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https"
          android:host="myapp.example.com" />
  </intent-filter>
</activity>
```

```json
// web/.well-known/assetlinks.json (Firebase Hosting で配信)
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.myapp",
    "sha256_cert_fingerprints": ["AA:BB:CC:..."]
  }
}]
```

## iOS: Universal Links 設定

```xml
<!-- ios/Runner/Runner.entitlements -->
<key>com.apple.developer.associated-domains</key>
<array>
  <string>applinks:myapp.example.com</string>
</array>
```

```json
// web/.well-known/apple-app-site-association
{
  "applinks": {
    "apps": [],
    "details": [{
      "appID": "TEAM_ID.com.example.myapp",
      "paths": ["*"]
    }]
  }
}
```

## go_router でディープリンクを処理

```dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/invite/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        return InvitePage(code: code);
      },
    ),
    GoRoute(
      path: '/share/:postId',
      builder: (context, state) {
        return PostDetailPage(postId: state.pathParameters['postId']!);
      },
    ),
  ],
);

// main.dart
MaterialApp.router(
  routerConfig: router,
  // go_router が自動でディープリンクを処理
)
```

## テスト (adb / simctl)

```bash
# Android
adb shell am start -W \
  -a android.intent.action.VIEW \
  -d "https://myapp.example.com/invite/ABC123"

# iOS Simulator
xcrun simctl openurl booted \
  "https://myapp.example.com/invite/ABC123"
```

## まとめ

```
Android       → App Links + assetlinks.json (autoVerify: true)
iOS           → Universal Links + apple-app-site-association
go_router     → path パラメータで自動処理 (手動 onGenerateRoute 不��)
テスト        → adb / xcrun simctl で実機相当確認
```

ディープリンクは「外部からアプリの特定画面に飛ばせる」体験を作る最重要機能の一つ。
