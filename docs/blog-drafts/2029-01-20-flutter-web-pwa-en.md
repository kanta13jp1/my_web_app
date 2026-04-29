---
title: "Flutter Web PWA Complete Guide — Offline Support, Install Prompt & Push Notifications"
tags: flutter,dart,ai,indiedev
published: true
---

# Flutter Web PWA Complete Guide — Offline Support, Install Prompt & Push Notifications

Turning your Flutter Web app into a Progressive Web App (PWA) delivers a near-native experience directly in the browser — complete with offline support, home screen installation, and push notifications.

## What is a PWA?

PWAs use web technologies to deliver app-like experiences. Key features:

- **Installable**: Add to home screen and launch like an app
- **Offline-first**: Service Worker caching means no network required
- **Push notifications**: Equivalent to native notifications
- **Fast loading**: Cache strategies make subsequent loads instant

Flutter Web includes PWA support out of the box.

## Flutter Web PWA Setup

```bash
# New project
flutter create --platforms=web my_pwa_app

# Add web to existing project
flutter create --platforms=web .
```

The `web/` directory is auto-generated with:

```
web/
  manifest.json    # PWA manifest
  index.html       # Service Worker already registered
  icons/           # App icons
```

## Customizing manifest.json

```json
{
  "name": "Jibun AI Life Management",
  "short_name": "JibunAI",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#ff6b35",
  "description": "AI-powered life management for your daily decisions",
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

## Offline Caching with Service Workers

Flutter Web auto-generates `flutter_service_worker.js` at build time. For custom strategies:

```javascript
// web/custom-service-worker.js
const CACHE_NAME = 'jibun-ai-v1';
const OFFLINE_URLS = ['/', '/index.html', '/main.dart.js'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(OFFLINE_URLS))
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((response) =>
      response || fetch(event.request).catch(() => caches.match('/index.html'))
    )
  );
});
```

## Controlling the Install Prompt

```dart
// lib/services/pwa_service.dart
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class PwaService {
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
    (_deferredPrompt as dynamic).prompt();
    _deferredPrompt = null;
  }

  static bool get isInstalled =>
      web.window.matchMedia('(display-mode: standalone)').matches;
}
```

```dart
// Install button widget
if (PwaService.isInstallable)
  ElevatedButton.icon(
    onPressed: PwaService.showInstallPrompt,
    icon: const Icon(Icons.download),
    label: const Text('Install App'),
  ),
```

## Push Notifications with Firebase Cloud Messaging

```dart
dependencies:
  firebase_messaging: ^15.0.0
```

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
final messaging = FirebaseMessaging.instance;

await messaging.requestPermission(alert: true, badge: true, sound: true);

final token = await messaging.getToken(vapidKey: 'your-vapid-key');
if (token != null) {
  await supabase.from('push_tokens').upsert({
    'user_id': supabase.auth.currentUser!.id,
    'token': token,
    'platform': 'web',
  });
}

FirebaseMessaging.onMessage.listen((message) {
  showInAppNotification(message.notification?.title ?? '');
});
```

## Build & Optimization

```bash
flutter build web --release --pwa-strategy offline-first
# pwa-strategy options: offline-first (recommended) | none
```

## Lighthouse Score Tips

Target PWA score 90+:
- HTTPS required (Firebase Hosting handles this automatically)
- Provide 192px + 512px icons
- Set `theme-color` meta tag
- Add `apple-touch-icon`

## Summary

PWA-ifying a Flutter Web app comes down to tuning `manifest.json` and the Service Worker. Add offline support and push notifications to close the gap with native apps.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
