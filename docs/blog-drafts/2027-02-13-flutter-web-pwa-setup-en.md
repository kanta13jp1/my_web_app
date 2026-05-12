---
title: "Flutter Web PWA Setup: Installable SPA in 10 Minutes"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter Web PWA Setup: Installable SPA in 10 Minutes

Flutter Web includes PWA support out of the box. With the right configuration, you get "Add to Home Screen," offline support, and push notifications. Here's the full setup from this production app.

## Flutter Web Ships PWA-Ready

```bash
flutter create my_app --platforms web
```

The generated `web/` directory already includes:
- `manifest.json`
- `service-worker.js`
- `index.html` with PWA meta tags

But default settings produce a Lighthouse PWA score in the 60s. Here's what needs tuning.

## Optimized manifest.json

```json
{
  "name": "自分株式会社",
  "short_name": "自分",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#FF6B00",
  "description": "AI-integrated life management app",
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
  "orientation": "portrait-primary",
  "categories": ["productivity", "lifestyle"],
  "lang": "ja"
}
```

`purpose: "any maskable"` enables Android adaptive icons. Without it, the icon gets clipped.

## index.html PWA Meta Tags

```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  
  <!-- PWA -->
  <meta name="theme-color" content="#FF6B00">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="自分">
  
  <!-- iOS icon (Safari ignores manifest.json icons) -->
  <link rel="apple-touch-icon" sizes="180x180" href="icons/Icon-192.png">
  
  <link rel="manifest" href="manifest.json">
  
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.register('flutter_service_worker.js');
      });
    }
  </script>
</head>
```

iOS Safari doesn't read `manifest.json` icons. The `apple-touch-icon` link is required separately.

## Service Worker Cache Headers (Firebase Hosting)

```json
// firebase.json
{
  "hosting": {
    "headers": [
      {
        "source": "flutter_service_worker.js",
        "headers": [{ "key": "Cache-Control", "value": "no-cache" }]
      },
      {
        "source": "**/*.dart.js",
        "headers": [{ "key": "Cache-Control", "value": "max-age=31536000" }]
      }
    ]
  }
}
```

`flutter_service_worker.js` must not be cached. If it's cached, users see stale versions after every deploy. `no-cache` forces re-fetch on every page load.

The compiled `.dart.js` can be cached aggressively — Flutter includes a content hash in the filename.

## Custom Install Prompt (beforeinstallprompt)

```dart
// lib/services/pwa_install_service.dart
import 'dart:js_interop';

class PwaInstallService {
  static bool _canInstall = false;
  
  static void initialize() {
    web.window.addEventListener('beforeinstallprompt', (event) {
      event.preventDefault();
      _canInstall = true;
      // Show custom "Install App" button
    }.toJS);
  }
  
  static bool get canInstall => _canInstall;
}
```

Catching `beforeinstallprompt` suppresses the browser's default prompt, letting you control when and where the install UI appears.

## Lighthouse PWA Checklist

| Check | Required Config |
|---|---|
| HTTPS | Firebase Hosting: automatic |
| Service Worker | `flutter_service_worker.js` registered |
| Valid manifest | name + icons (192px + 512px) + start_url + display |
| Offline response | SW provides cached fallback |
| `theme-color` meta | Set in index.html |

## What You Get After Setup

- **Home screen install**: Users add the app without visiting a store
- **Google Play via TWA**: Flutter Web PWAs can be published to Google Play via Trusted Web Activity
- **Offline access**: `--pwa-strategy=offline-first` caches all assets in the service worker

## Summary

Four things that matter for Flutter Web PWA:
1. `purpose: "any maskable"` in manifest.json — required for adaptive icons
2. `flutter_service_worker.js` must be `no-cache` — every deploy needs a fresh worker
3. Add `apple-touch-icon` separately — Safari ignores manifest icons
4. Catch `beforeinstallprompt` — control the install flow with your own UI

Flutter Web is a real web app and a real PWA at the same time. That flexibility is one of the main reasons this stack chose Flutter over React or Vue.
