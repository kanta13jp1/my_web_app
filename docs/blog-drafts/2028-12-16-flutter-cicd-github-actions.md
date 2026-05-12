---
title: "Flutter CI/CD — GitHub Actions でテスト・ビルド・デプロイを自動化"
tags: flutter,AI,個人開発,automation
published: true
---

# Flutter CI/CD — GitHub Actions でテスト・ビルド・デプロイを自動化

push のたびに手動ビルド・デプロイするのは時間の無駄。GitHub Actions で全自動化する構成をまとめる。

## 基本パイプライン構成

```yaml
# .github/workflows/flutter-ci.yml
name: Flutter CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: stable
          cache: true

      - name: Install dependencies
        run: flutter pub get

      - name: Check formatting
        run: dart format --set-exit-if-changed .

      - name: Analyze
        run: flutter analyze

      - name: Run tests
        run: flutter test --coverage
```

## Web ビルド & Firebase Hosting デプロイ

```yaml
  deploy-web:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          cache: true

      - run: flutter pub get
      - run: flutter build web --release --web-renderer canvaskit

      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: my-web-app-b67f4
```

## Android APK ビルド (PR プレビュー用)

```yaml
  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          cache: true

      - run: flutter pub get
      - run: flutter build apk --debug

      - uses: actions/upload-artifact@v4
        with:
          name: debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
```

## まとめ

```
test job       → format / analyze / test --coverage (PR/push 毎)
deploy-web     → flutter build web → Firebase Hosting (main push のみ)
build-android  → debug APK → artifact 保存 (PR レビュー用)
cache          → subosito/flutter-action の cache: true で 60秒短縮
```

CI/CD は「一度作れば永久に動く」資産。初期投資 2 時間で毎回のデプロイ作業をゼロにできる。
