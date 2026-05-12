---
title: "Flutter CI/CD — Automating Tests, Builds, and Deploys with GitHub Actions"
tags: flutter,ai,indiedev,automation
published: true
---

# Flutter CI/CD — Automating Tests, Builds, and Deploys with GitHub Actions

Manually building and deploying on every push is a waste of time. Here's a complete GitHub Actions setup that automates everything.

## Core Pipeline

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

## Web Build & Firebase Hosting Deploy

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

## Android APK Build (PR Previews)

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

## Summary

```
test job       → format / analyze / test --coverage (every PR and push)
deploy-web     → flutter build web → Firebase Hosting (main push only)
build-android  → debug APK → artifact upload (for PR reviewers)
cache          → subosito/flutter-action cache: true saves ~60s per run
```

CI/CD is a one-time investment that pays off forever. Two hours of setup eliminates manual deploy work on every future change.
