---
title: "Flutter WebをPWA化する — manifest.json・Service Worker・インストール促進UI"
tags: Flutter,PWA,個人開発,buildinpublic,webdev
published: true
---

# Flutter WebをPWA化する

## PWA化の効果

Flutter Web アプリを PWA (Progressive Web App) にすると:

- ホーム画面に追加できる (アプリアイコン)
- オフライン動作が可能になる
- インストール促進バナーを表示できる
- iOS Safari でスタンドアロン表示

## 1. manifest.json の設定

`web/manifest.json` を正しく設定する:

```json
{
  "name": "自分株式会社",
  "short_name": "自分株式会社",
  "description": "21競合SaaSを1つに統合するAIライフマネジメントアプリ",
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

`"purpose": "maskable"` のアイコンがないと Android でアイコンが白い丸になる。

## 2. index.html のリンク確認

```html
<head>
  <link rel="manifest" href="manifest.json">
  <meta name="theme-color" content="#FF6B00">
  <!-- iOS 用 -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="自分株式会社">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
</head>
```

iOS は `manifest.json` を無視するため、`apple-mobile-web-app-*` メタタグが必要。

## 3. Service Worker (Flutter デフォルト)

Flutter Web はデフォルトで `flutter_service_worker.js` を生成する。
`web/index.html` にすでに含まれているため、追加設定は不要:

```html
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function() {
      navigator.serviceWorker.register('/flutter_service_worker.js');
    });
  }
</script>
```

## 4. インストール促進 UI (Flutter)

```dart
class PwaInstallBanner extends StatefulWidget {
  // ...
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.install_mobile, color: AppColors.orange),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'ホーム画面に追加してオフラインでも使えます',
                style: TextStyle(color: AppColors.onSurface),
              ),
            ),
            TextButton(
              onPressed: _triggerInstall,
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerInstall() {
    // JavaScript interop でbeforeinstallpromptを呼び出す
    // dart:js_interop を使う
  }
}
```

## 5. Lighthouse PWA スコアの確認

Chrome DevTools → Lighthouse → PWA を実行:

| チェック項目 | 対応方法 |
|------------|---------|
| Web app manifest | manifest.json + link要素 |
| Service Worker | Flutter自動生成 |
| HTTPS | Firebase Hosting = デフォルトHTTPS |
| Icons | 192px + 512px + maskable |
| Offline | Service Worker キャッシュ |

Firebase Hosting を使えば HTTPS は自動。

## まとめ

Flutter Web の PWA 化は:
1. `manifest.json` のアイコン・テーマカラー設定
2. `index.html` の iOS 用メタタグ追加
3. Service Worker はデフォルトで有効

最小工数でネイティブアプリに近い体験を提供できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #PWA #buildinpublic #個人開発 #webdev
