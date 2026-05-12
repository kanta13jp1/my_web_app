---
title: "Indie Dev CI/CD Design — GitHub Actions + Firebase Auto-Deploy to Production"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# Indie Dev CI/CD Design — GitHub Actions + Firebase Auto-Deploy to Production

Push code, see it live in 5 minutes. That's the indie dev CI/CD ideal.

## Basic Setup

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
          cache: true  # saves ~2 minutes per run

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

## Test → Build → Deploy in Order

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
    needs: test  # only deploys when tests pass
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

## Preview Deploy (for PR Reviews)

```yaml
# Auto-generate a preview URL when a PR is opened
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
          # omit channelId → auto-deploys to pr-123 channel
          projectId: my-app-12345
          # preview URL is automatically posted as a PR comment
```

## Deployment Verification Step

```yaml
      - name: Verify deployment
        run: |
          # Confirm the new commit hash is live
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

## Summary

```
Basic setup       → push to main → flutter build → firebase deploy (~5 min)
Test gate         → needs: test ensures tests pass before deploy
Preview deploy    → auto preview URL on every PR (faster reviews)
Deploy verify     → poll version.json to confirm the new build is actually live
```

Set up CI/CD once and don't touch it. Only revisit when something breaks.
