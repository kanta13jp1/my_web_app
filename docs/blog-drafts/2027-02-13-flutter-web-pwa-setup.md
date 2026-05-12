---
title: "Flutter Web を PWA 化する — インストール可能な SPA を10分で作る"
tags: flutter,AI,個人開発,buildinpublic
published: true
---

# Flutter Web を PWA 化する — インストール可能な SPA を10分で作る

Flutter Web のデフォルト設定でも PWA として動きますが、きちんと設定すれば「ホーム画面に追加」「オフライン対応」「プッシュ通知」まで実装できます。このプロジェクトで実際に設定した内容を全部公開します。

## Flutter Web はデフォルトで PWA 対応済み

```bash
flutter create my_app --platforms web
```

作成直後の `web/` ディレクトリには既に:
- `manifest.json` (PWA マニフェスト)
- `service-worker.js` (キャッシュ戦略)
- `index.html` (PWA メタタグ)

が含まれています。ただしデフォルト設定のままでは Lighthouse の PWA スコアが 60点台になる。

## manifest.json の最適化

```json
{
  "name": "自分株式会社",
  "short_name": "自分",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#FF6B00",
  "description": "AI統合ライフマネジメントアプリ",
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
  "lang": "ja",
  "dir": "ltr"
}
```

`purpose: "any maskable"` が重要。Android の「適応型アイコン」に対応。

## index.html の PWA メタタグ

```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  
  <!-- PWA 必須メタタグ -->
  <meta name="theme-color" content="#FF6B00">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="自分">
  
  <!-- iOS アイコン (Safariは manifest.json を読まない) -->
  <link rel="apple-touch-icon" sizes="180x180" href="icons/Icon-192.png">
  
  <!-- manifest -->
  <link rel="manifest" href="manifest.json">
  
  <!-- Service Worker 登録 -->
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', function () {
        navigator.serviceWorker.register('flutter_service_worker.js');
      });
    }
  </script>
</head>
```

iOS Safari は `manifest.json` の `icons` を読まない。`apple-touch-icon` を別途指定する必要がある。

## Service Worker: キャッシュ戦略

Flutter Web の `flutter_service_worker.js` は自動生成されますが、Firebase Hosting のキャッシュヘッダーと組み合わせて調整が必要:

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

`flutter_service_worker.js` をキャッシュしてしまうと、デプロイ後も古いバージョンが使われ続ける。`no-cache` 必須。

## インストールプロンプト (beforeinstallprompt)

```dart
// lib/services/pwa_install_service.dart
import 'dart:js_interop';

class PwaInstallService {
  static bool _canInstall = false;
  
  static void initialize() {
    // beforeinstallprompt イベントをキャッチ
    web.window.addEventListener('beforeinstallprompt', (event) {
      event.preventDefault();
      _canInstall = true;
      // カスタムボタンでプロンプト表示
    }.toJS);
  }
  
  static bool get canInstall => _canInstall;
}
```

`beforeinstallprompt` をキャッチしてデフォルトを抑制 → カスタムタイミングで「インストール」ボタンを表示する。

## Lighthouse PWA スコアの確認ポイント

| チェック項目 | 必須設定 |
|---|---|
| HTTPS | Firebase Hosting は自動対応 |
| Service Worker 登録 | `flutter_service_worker.js` が登録済みか |
| manifest.json 有効 | name / icons(192px+512px) / start_url / display |
| オフライン対応 | SW がキャッシュをフォールバック提供 |
| `theme-color` meta | index.html に設定 |

## 実装後の変化

- Google Play ストア掲載 → Flutter Web PWA は TWA (Trusted Web Activity) 経由で可能
- 「ホーム画面に追加」 → ユーザーリテンション向上 (毎回 URL 入力不要)
- オフラインアクセス → Flutter の `--pwa-strategy=offline-first` で全アセットをキャッシュ

## まとめ

Flutter Web の PWA 化で押さえるポイント:
1. `manifest.json` の `purpose: "any maskable"` でアダプティブアイコン対応
2. `flutter_service_worker.js` は `no-cache` — デプロイ反映を確実に
3. iOS Safari 向けに `apple-touch-icon` を別途指定
4. `beforeinstallprompt` を使ってカスタムインストールボタンを実装

Flutter Web は Web としても使え、PWA としてもアプリとして使える。この柔軟性が Flutter を選んだ理由の一つです。
