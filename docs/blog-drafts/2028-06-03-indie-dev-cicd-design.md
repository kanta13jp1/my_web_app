---
title: "個人開発者の CI/CD 設計 — GitHub Actions + Firebase で本番自動デプロイ"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# 個人開発者の CI/CD 設計 — GitHub Actions + Firebase で本番自動デプロイ

コードを push したら 5 分後に本番反映。それが個人開発 CI/CD の理想形。

## 基本構成

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
          channel: stable
          cache: true  # キャッシュで 2分短縮

      - name: Build Flutter Web
        run: flutter build web --release --web-renderer canvaskit

      - name: Deploy to Firebase Hosting
        uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: my-app-12345
```

## テスト → ビルド → デプロイの順序

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { cache: true }
      - run: flutter test

  deploy:
    needs: test  # test が通った時だけデプロイ
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { cache: true }
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: my-app-12345
```

## Preview Deploy (PR レビュー用)

```yaml
# PR を開いたら preview URL を自動生成
on:
  pull_request:
    branches: [main]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with: { cache: true }
      - run: flutter build web --release
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          # channelId 省略 → 自動で pr-123 チャンネルに deploy
          projectId: my-app-12345
          # PR コメントに preview URL が自動投稿される
```

## デプロイ検証ステップ

```yaml
      - name: Verify deployment
        run: |
          # main.dart.js の commit hash がデプロイされたか確認
          for i in 1 2 3 4; do
            DEPLOYED=$(curl -s https://my-app.web.app/version.json | jq -r '.commit')
            if [ "$DEPLOYED" = "${{ github.sha }}" ]; then
              echo "✅ Deploy verified: $DEPLOYED"
              exit 0
            fi
            echo "Waiting... ($i/4)"
            sleep 15
          done
          echo "❌ Deploy verification failed"
          exit 1
```

## まとめ

```
基本構成     → push to main → flutter build → firebase deploy (5分)
テスト順序   → needs: test で品質ゲート (テスト失敗→デプロイ停止)
Preview      → PR 自動で preview URL (レビュー効率 ↑)
デプロイ検証 → version.json で実際に反映されたかポーリング確認
```

CI/CD は「動く仕組み」を作ったら触らない。壊れたときだけ直す。
