---
title: "Making Your Flutter Web App a PWA — manifest.json, Service Worker, Install Prompt"
tags: Flutter,PWA,buildinpublic,webdev,mobile
published: true
---

# Making Your Flutter Web App a PWA

## Why PWA Matters for Flutter Web

A properly configured PWA gives Flutter Web apps:

- Home screen install (with real app icon)
- Offline capability via Service Worker cache
- Install promotion banner in-app
- Standalone display on iOS Safari (no browser chrome)

## 1. Configure manifest.json

```json
{
  "name": "My App",
  "short_name": "My App",
  "description": "Your app description",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#0A0A0A",
  "theme_color": "#FF6B00",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-maskable-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

Without `"purpose": "maskable"`, Android will render your icon as a tiny image in a white circle.

## 2. iOS-Specific Meta Tags in index.html

iOS Safari ignores `manifest.json` entirely. Add these to `web/index.html`:

```html
<head>
  <link rel="manifest" href="manifest.json">
  <meta name="theme-color" content="#FF6B00">

  <!-- iOS PWA config -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="My App">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
</head>
```

Skip these and your app won't behave as a standalone app on iPhone.

## 3. Service Worker — Flutter Handles It

Flutter Web auto-generates `flutter_service_worker.js` at build time. The default `index.html` already registers it:

```html
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
      navigator.serviceWorker.register('/flutter_service_worker.js');
    });
  }
</script>
```

No extra configuration needed. The service worker handles asset caching automatically.

## 4. In-App Install Banner

```dart
class PwaInstallBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.install_mobile),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Add to home screen for offline access'),
          ),
          TextButton(
            onPressed: _triggerNativeInstallPrompt,
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }

  void _triggerNativeInstallPrompt() {
    // Use dart:js_interop to call the beforeinstallprompt event
  }
}
```

Show this banner after a few sessions to avoid being intrusive on first visit.

## 5. Lighthouse PWA Checklist

Run Chrome DevTools → Lighthouse → PWA to audit:

| Requirement | Solution |
|-------------|---------|
| Web app manifest | manifest.json + `<link rel="manifest">` |
| Service Worker | Flutter auto-generates |
| HTTPS | Firebase Hosting (default) |
| Icons (192 + 512) | Add both to manifest icons array |
| Maskable icon | Add `"purpose": "maskable"` variant |
| Offline behavior | Service Worker cache |

Firebase Hosting automatically provides HTTPS, which is required for PWA.

## Result

After these changes, users on Android Chrome will see a "Add to Home Screen" banner. iOS users can use the Share menu → "Add to Home Screen".

The app icon appears on the home screen, launches full-screen, and works offline for cached assets — all without an App Store submission.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #PWA #buildinpublic #webdev #mobile
