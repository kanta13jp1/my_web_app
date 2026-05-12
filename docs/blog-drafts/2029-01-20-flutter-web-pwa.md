---
title: "Flutter Web を PWA 化する完全ガイド — オフライン対応・インストール・Push 通知"
tags: flutter,dart,AI,個人開発
published: true
---

# Flutter Web を PWA 化する完全ガイド — オフライン対応・インストール・Push 通知

Flutter Web アプリを Progressive Web App (PWA) にすることで、ネイティブアプリに近い体験を Web ブラウザ上で実現できます。オフライン対応・ホーム画面追加・Push 通知の実装方法を解説します。

## PWA とは

PWA は Web 技術でネイティブアプリ的な体験を提供する仕組みです。主な特徴:

- **インストール可能**: ホーム画面に追加 → アイコンから起動
- **オフライン動作**: Service Worker でキャッシュ → ネット不要
- **Push 通知**: ネイティブ通知と同等
- **高速ロード**: キャッシュ戦略で初回以降は爆速

Flutter Web はデフォルトで PWA サポートが組み込まれています。

## Flutter Web の PWA 設定確認

```bash
# 新規プロジェクト
flutter create --platforms=web my_pwa_app

# 既存プロジェクトへ Web 追加
flutter create --platforms=web .
```

`web/` ディレクトリに以下が自動生成されます:

```
web/
  manifest.json    # PWA マニフェスト
  index.html       # Service Worker 登録済み
  icons/           # アプリアイコン
```

## manifest.json のカスタマイズ

```json
{
  "name": "自分株式会社 AI ライフマネジメント",
  "short_name": "自分AI",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#ff6b35",
  "description": "AIがあなたの毎日をサポートするライフマネジメントアプリ",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
```

## Service Worker によるオフラインキャッシュ

Flutter Web のデフォルト Service Worker (`flutter_service_worker.js`) はビルド時に自動生成されます。カスタム戦略が必要な場合:

```javascript
// web/custom-service-worker.js
const CACHE_NAME = 'jibun-ai-v1';
const OFFLINE_URLS = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/assets/AssetManifest.json',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(OFFLINE_URLS);
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) => {
      // キャッシュ優先 → なければネットワーク
      return response || fetch(event.request).catch(() => {
        return caches.match('/index.html');
      });
    })
  );
});
```

## インストールプロンプトの制御

```dart
// lib/services/pwa_service.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class PwaService {
  // beforeinstallprompt イベントをキャプチャ
  static web.Event? _deferredPrompt;

  static void initialize() {
    web.window.addEventListener('beforeinstallprompt', (event) {
      event.preventDefault();
      _deferredPrompt = event;
    }.toJS);
  }

  static bool get isInstallable => _deferredPrompt != null;

  static Future<void> showInstallPrompt() async {
    if (_deferredPrompt == null) return;
    // プロンプト表示
    (_deferredPrompt as dynamic).prompt();
    _deferredPrompt = null;
  }

  static bool get isInstalled =>
      web.window.matchMedia('(display-mode: standalone)').matches;
}
```

```dart
// インストールボタン (Widget)
if (PwaService.isInstallable)
  ElevatedButton.icon(
    onPressed: PwaService.showInstallPrompt,
    icon: const Icon(Icons.download),
    label: const Text('アプリをインストール'),
  ),
```

## Push 通知 (Firebase Cloud Messaging)

```dart
// pubspec.yaml
dependencies:
  firebase_messaging: ^15.0.0
```

```dart
// main.dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
final messaging = FirebaseMessaging.instance;

// 通知許可
await messaging.requestPermission(
  alert: true,
  badge: true,
  sound: true,
);

// FCM トークン取得 → Supabase に保存
final token = await messaging.getToken(
  vapidKey: 'your-vapid-key',
);
if (token != null) {
  await supabase.from('push_tokens').upsert({
    'user_id': supabase.auth.currentUser!.id,
    'token': token,
    'platform': 'web',
  });
}

// フォアグラウンド通知処理
FirebaseMessaging.onMessage.listen((message) {
  // アプリ内通知 UI を表示
  showInAppNotification(message.notification?.title ?? '');
});
```

## ビルドと最適化

```bash
# PWA ビルド
flutter build web --release --pwa-strategy offline-first

# pwa-strategy オプション:
# offline-first: キャッシュ優先 (推奨)
# none: Service Worker 無効
```

## Lighthouse スコア改善

```bash
# Chrome DevTools → Lighthouse → PWA 監査
# 目標: PWA スコア 90+
```

改善ポイント:
- HTTPS 必須 (Firebase Hosting は自動対応)
- アイコン 192px + 512px を用意
- `theme-color` meta タグ設定
- `apple-touch-icon` 設定

## まとめ

Flutter Web の PWA 化は `manifest.json` と Service Worker の調整だけで実現できます。オフライン対応と Push 通知を加えることで、ネイティブアプリと遜色ない体験を提供できます。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
