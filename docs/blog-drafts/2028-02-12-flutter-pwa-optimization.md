---
title: "Flutter PWA 最適化 — Service Worker / オフライン / インストール体験"
tags: flutter,AI,個人開発,programming
published: true
---

# Flutter PWA 最適化 — Service Worker / オフライン / インストール体験

Flutter Web を PWA として最適化する。インストール促進・オフライン対応・キャッシュ戦略の3点を整理する。

## PWA の基本要件

```
Flutter Web は標準で PWA 対応済み:
  - manifest.json → インストール情報
  - service worker → オフライン対応
  - HTTPS → 必須

flutter build web --pwa-strategy=offline-first
  → Service Worker がアセットを事前キャッシュ
```

## manifest.json のカスタマイズ

```json
{
  "name": "自分株式会社",
  "short_name": "自分株",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#f97316",
  "description": "AIライフマネジメントアプリ",
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

## インストールプロンプトを Flutter から制御

```dart
// JavaScript と通信してインストール促進
import 'dart:js_interop';

@JS('window.deferredPrompt')
external JSAny? get deferredPrompt;

@JS('window.promptInstall')
external JSPromise promptInstall();

// インストール可能かチェック
bool get canInstallPwa => deferredPrompt != null;

// インストールダイアログを表示
Future<void> showInstallPrompt() async {
  if (!canInstallPwa) return;
  await promptInstall().toDart;
}
```

```javascript
// web/index.html の <script> に追加
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

**インストール誘導 UI**:

```dart
// 3回目のセッションでバナー表示
class InstallBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!canInstallPwa) return const SizedBox.shrink();
    return MaterialBanner(
      content: const Text('ホーム画面に追加してオフラインでも使えます'),
      actions: [
        TextButton(
          onPressed: showInstallPrompt,
          child: const Text('インストール'),
        ),
        TextButton(
          onPressed: () => _dismissBanner(),
          child: const Text('後で'),
        ),
      ],
    );
  }
}
```

## Service Worker キャッシュ戦略

```javascript
// flutter_service_worker.js を上書き (flutter build web 後)
// Cache-First: アセット (画像・フォント)
// Network-First: API レスポンス

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Supabase API は常にネットワーク優先
  if (url.hostname.includes('supabase')) {
    event.respondWith(
      fetch(event.request).catch(() =>
        caches.match('/offline.html')
      )
    );
    return;
  }

  // アセットはキャッシュ優先
  event.respondWith(
    caches.match(event.request).then((cached) =>
      cached || fetch(event.request)
    )
  );
});
```

## オフライン対応: Hive でローカルキャッシュ

```dart
// Supabase が取れない場合はローカルキャッシュを表示
Future<List<Task>> getTasks() async {
  try {
    final online = await supabase
      .from('tasks')
      .select()
      .order('created_at');
    // 成功したらキャッシュを更新
    await _cache.put('tasks', jsonEncode(online));
    return online.map(Task.fromJson).toList();
  } catch (e) {
    // オフライン時はキャッシュを返す
    final cached = _cache.get('tasks');
    if (cached != null) {
      return (jsonDecode(cached) as List).map(Task.fromJson).toList();
    }
    return [];
  }
}
```

## まとめ

```
manifest.json    → name/icon/theme/screenshots を正しく設定
インストール誘導 → beforeinstallprompt + Flutter から制御
Service Worker   → Supabase API = Network-First / アセット = Cache-First
オフライン対応   → Hive でローカルキャッシュ
```

Flutter PWA は標準で多くが揃っている。manifest と Service Worker を調整するだけでネイティブアプリに近い体験になる。

