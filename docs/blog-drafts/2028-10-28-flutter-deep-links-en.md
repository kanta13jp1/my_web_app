---
title: "Flutter Deep Links — App Links, Universal Links, and go_router Integration"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Deep Links — App Links, Universal Links, and go_router Integration

Implementing deep links that open the app from both `myapp://` and `https://` URLs.

## Android: App Links Setup

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
// web/.well-known/assetlinks.json (served from Firebase Hosting)
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.myapp",
    "sha256_cert_fingerprints": ["AA:BB:CC:..."]
  }
}]
```

## iOS: Universal Links Setup

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

## Handle Deep Links with go_router

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
  // go_router handles deep links automatically
)
```

## Testing (adb / simctl)

```bash
# Android
adb shell am start -W \
  -a android.intent.action.VIEW \
  -d "https://myapp.example.com/invite/ABC123"

# iOS Simulator
xcrun simctl openurl booted \
  "https://myapp.example.com/invite/ABC123"
```

## Summary

```
Android       → App Links + assetlinks.json (autoVerify: true)
iOS           → Universal Links + apple-app-site-association
go_router     → path parameters handled automatically (no manual onGenerateRoute)
Testing       → adb / xcrun simctl for device-equivalent verification
```

Deep links are one of the highest-impact features — they let you navigate directly to any screen from outside the app.
