---
title: "Deploying Flutter Web to Firebase Hosting with GitHub Actions CI/CD"
tags: Flutter,Firebase,CI/CD,buildinpublic,webdev
published: true
---

# Deploying Flutter Web to Firebase Hosting with GitHub Actions CI/CD

## Why Firebase Hosting?

| Option | Pros | Cons |
|--------|------|------|
| **Firebase Hosting** | Free, auto-HTTPS, CDN, easy GitHub Actions | Google dependency |
| Vercel | Feature-rich | Flutter-specific config is complex |
| GitHub Pages | Free | Manual HTTPS setup |

For Flutter Web, Firebase Hosting is the fastest path to production.

## 1. Firebase CLI Setup

```bash
npm install -g firebase-tools
firebase login
cd your-flutter-project
firebase init hosting
```

Answer `firebase init hosting`:
- Public directory: `build/web`
- Configure as SPA: **Yes**
- Automatic builds via GitHub: No (we'll configure manually)

## 2. firebase.json Configuration

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "**", "destination": "/index.html" }
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

`rewrites` → all routes serve `index.html` (required for Flutter's client-side router).
`headers` → JS/WASM cached for 1 year (safe because filenames are hashed per build).

## 3. GitHub Actions Workflow

```yaml
# .github/workflows/deploy-prod.yml
name: Deploy to Production
on:
  push:
    branches: [main]
    paths: ['lib/**', 'web/**', 'pubspec.yaml']
    paths-ignore: ['docs/**', '**.md']

concurrency:
  group: deploy-prod
  cancel-in-progress: false  # queue all commits

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.32.x'
          channel: stable
          cache: true

      - run: flutter build web --release --web-renderer canvaskit

      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: your-project-id
```

## 4. Service Account Secret

```bash
# Firebase Console → Project Settings → Service Accounts
# → Generate new private key → Download JSON
# GitHub repo → Settings → Secrets → FIREBASE_SERVICE_ACCOUNT → paste JSON
```

## 5. Verify the Deployment

```bash
# Check deploy status
gh run list --workflow=deploy-prod.yml --limit 3

# Confirm live URL
curl -I https://your-project.web.app/
```

## Concurrency Note

With multiple parallel instances pushing to `main`, set `cancel-in-progress: false`. All commits queue and deploy in order — no commit gets skipped.

## Cost

Firebase Hosting free tier:
- 10 GB/month transfer
- 1 GB storage

Solo SaaS traffic is well within free tier.

## Summary

1. `firebase init hosting` → point to `build/web`
2. SPA rewrites + long-cache headers in `firebase.json`
3. GitHub Actions: `flutter build web --release` → `firebase deploy`
4. Store service account JSON as `FIREBASE_SERVICE_ACCOUNT` secret

First deploy to live URL in under 30 minutes.

---
Building in public: https://my-web-app-b67f4.web.app/
#Flutter #Firebase #CI/CD #buildinpublic #webdev
