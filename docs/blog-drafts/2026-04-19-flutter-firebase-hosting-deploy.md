---
title: "Flutter WebをFirebase Hostingにデプロイする完全ガイド — GitHub Actions CI/CD込み"
tags: Flutter,Firebase,CI/CD,個人開発,buildinpublic
published: true
---

# Flutter WebをFirebase Hostingにデプロイする完全ガイド

## なぜ Firebase Hosting か

| 選択肢 | メリット | デメリット |
|--------|---------|---------|
| **Firebase Hosting** | 無料・HTTPS自動・CDN・GitHub Actions連携簡単 | Google依存 |
| Vercel | 高機能 | Flutter専用設定が複雑 |
| GitHub Pages | 無料 | HTTPS設定が手動 |

Flutter Web + Firebase Hosting が最速で本番公開できる組み合わせ。

## 1. Firebase CLI のセットアップ

```bash
npm install -g firebase-tools
firebase login
cd your-flutter-project
firebase init hosting
```

`firebase init hosting` の回答:
- Public directory: `build/web`
- Configure as SPA: **Yes**
- Automatic builds: No (GitHub Actionsで管理)

## 2. firebase.json の設定

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css|wasm)",
        "headers": [
          { "key": "Cache-Control", "value": "max-age=31536000" }
        ]
      }
    ]
  }
}
```

`"rewrites"` でSPA対応 — Flutter Web のルーティングに必須。
`headers` でJSファイルを1年キャッシュ (ビルドごとにハッシュが変わるため安全)。

## 3. GitHub Actions でCI/CDを設定

```yaml
# .github/workflows/deploy-prod.yml
name: Deploy to Production
on:
  push:
    branches: [main]
    paths:
      - 'lib/**'
      - 'web/**'
      - 'pubspec.yaml'

concurrency:
  group: deploy-prod
  cancel-in-progress: false  # 全 commit をキューで処理

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.x'
          channel: stable
          cache: true

      - name: Build Flutter Web
        run: flutter build web --release --web-renderer canvaskit

      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: your-project-id
```

## 4. Service Account の設定

```bash
# Firebase Console → Project Settings → Service Accounts
# → Generate new private key → JSON をダウンロード
# GitHub → Settings → Secrets → FIREBASE_SERVICE_ACCOUNT にJSONを貼る
```

## 5. カスタムドメインの設定 (任意)

Firebase Console → Hosting → Add custom domain:
1. `example.com` を入力
2. DNS に TXT レコードを追加 (所有権確認)
3. A レコードを Firebase の IP に向ける
4. SSL は自動発行 (5分程度)

## デプロイの確認

```bash
# CLI で確認
firebase hosting:channel:list

# GHA で確認
gh run list --workflow=deploy-prod.yml --limit 3
```

本番URL: `https://your-project.web.app/`

## まとめ

1. `firebase init hosting` → `build/web` を指定
2. `firebase.json` に SPA rewrites + キャッシュヘッダー
3. GitHub Actions で `flutter build web --release` → `firebase deploy`
4. Service Account を GitHub Secrets に設定

コスト: 無料枠 (月10GB転送 / 1GB ストレージ) で個人開発は十分。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Flutter #Firebase #CI/CD #buildinpublic #個人開発
