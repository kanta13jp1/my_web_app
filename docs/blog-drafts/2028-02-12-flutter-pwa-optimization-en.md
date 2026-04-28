---
title: "Flutter PWA Optimization: Service Worker, Offline Support, and Install Prompts"
tags: flutter,ai,indiedev,programming
published: true
---

# Flutter PWA Optimization: Service Worker, Offline Support, and Install Prompts

Flutter Web ships with PWA support built in. Here's how to tune it: install prompt control, offline data, and cache strategy.

## PWA Baseline

```
Flutter Web is PWA-ready out of the box:
  - manifest.json → install metadata
  - service worker → offline support
  - HTTPS → required

flutter build web --pwa-strategy=offline-first
  → service worker pre-caches all assets
```

## Customize manifest.json

```json
{
  "name": "My App",
  "short_name": "MyApp",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#f97316",
  "description": "AI life management app",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable any"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable any"
    }
  ],
  "screenshots": [
    {
      "src": "screenshots/home.png",
      "sizes": "390x844",
      "type": "image/png",
      "form_factor": "narrow"
    }
  ]
}
```

## Control the Install Prompt from Flutter

```dart
import 'dart:js_interop';

@JS('window.deferredPrompt')
external JSAny? get deferredPrompt;

@JS('window.promptInstall')
external JSPromise promptInstall();

bool get canInstallPwa => deferredPrompt != null;

Future<void> showInstallPrompt() async {
  if (!canInstallPwa) return;
  await promptInstall().toDart;
}
```

```javascript
// Add to <script> in web/index.html
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  window.deferredPrompt = e;
});

window.promptInstall = async () => {
  if (!window.deferredPrompt) return;
  window.deferredPrompt.prompt();
  const { outcome } = await window.deferredPrompt.userChoice;
  window.deferredPrompt = null;
  return outcome;
};
```

**Install banner**:

```dart
class InstallBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!canInstallPwa) return const SizedBox.shrink();
    return MaterialBanner(
      content: const Text('Add to home screen for offline access'),
      actions: [
        TextButton(
          onPressed: showInstallPrompt,
          child: const Text('Install'),
        ),
        TextButton(
          onPressed: _dismissBanner,
          child: const Text('Later'),
        ),
      ],
    );
  }
}
```

## Service Worker Cache Strategy

```javascript
// Override flutter_service_worker.js after flutter build web
// Cache-First: assets (images, fonts)
// Network-First: API responses

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Supabase API → always network-first
  if (url.hostname.includes('supabase')) {
    event.respondWith(
      fetch(event.request).catch(() => caches.match('/offline.html'))
    );
    return;
  }

  // Assets → cache-first
  event.respondWith(
    caches.match(event.request).then((cached) =>
      cached || fetch(event.request)
    )
  );
});
```

## Offline Data with Hive

```dart
Future<List<Task>> getTasks() async {
  try {
    final online = await supabase
      .from('tasks')
      .select()
      .order('created_at');
    await _cache.put('tasks', jsonEncode(online));
    return online.map(Task.fromJson).toList();
  } catch (_) {
    // Offline: return cached data
    final cached = _cache.get('tasks');
    if (cached != null) {
      return (jsonDecode(cached) as List).map(Task.fromJson).toList();
    }
    return [];
  }
}
```

## Summary

```
manifest.json   → name, icon, theme_color, screenshots
Install prompt  → intercept beforeinstallprompt + call from Flutter
Service Worker  → Supabase = Network-First / assets = Cache-First
Offline data    → Hive local cache fallback
```

Flutter PWA already covers 80% of the work. Tune manifest and the service worker and you get a near-native install experience.

