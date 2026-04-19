---
title: "GitHub Actions Concurrency Patterns — cancel-in-progress: false for Parallel Deployments"
tags: GitHubActions,CI/CD,Flutter,buildinpublic,webdev
published: true
---

# GitHub Actions Concurrency Patterns

## The Problem: 5 Instances, All Pushing to Main

Running 5 parallel Claude Code instances means bursts of commits to `main`. Without concurrency configuration, deploy workflows pile up:

- 5 simultaneous deploys competing for resources
- Possible race condition where an older build overwrites a newer one
- Timeouts from resource contention

## `cancel-in-progress: false` is the Right Call for Deploys

```yaml
# .github/workflows/deploy-prod.yml
concurrency:
  group: deploy-prod
  cancel-in-progress: false  # queue mode — all runs execute in order
```

The key distinction:

| Use case | `cancel-in-progress` |
|----------|---------------------|
| CI (PR builds) | `true` — old PR builds are throwaway |
| Production deploy | `false` — every commit should ship |
| Blog publishing | `false` — don't skip any post |
| Scheduled tasks | `false` — never skip a scheduled run |

## Concurrency Group Design

```yaml
# ❌ Single group for everything — all workflows block each other
concurrency:
  group: ci

# ✅ Separate by workflow
concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false

# ✅ Per-PR CI — cancel old builds for the same PR
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Full Deploy Config for Parallel Pushes

```yaml
name: Deploy to Production
concurrency:
  group: deploy-prod
  cancel-in-progress: false

on:
  push:
    branches: [main]
    paths:
      - 'lib/**'
      - 'web/**'
      - 'pubspec.yaml'
    paths-ignore:
      - 'docs/**'
      - '**.md'

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - run: firebase deploy --only hosting
```

## Always Set `timeout-minutes`

Without it, a hung job runs for 6 hours and blocks the concurrency queue:

```yaml
jobs:
  build:
    timeout-minutes: 20   # Flutter Web build: ~10-15 min
  deploy:
    timeout-minutes: 10   # Firebase deploy: ~3-5 min
  lint:
    timeout-minutes: 5    # flutter analyze: ~2 min
```

## Filter Triggers With `paths-ignore`

```yaml
on:
  push:
    paths-ignore:
      - 'docs/**'
      - '**.md'
      - '.claude/**'
      - 'memory/**'
```

Doc-only commits don't need a full deploy. With 5 active instances writing docs frequently, this saves significant CI minutes.

## Summary

```
deploys:         cancel-in-progress: false (queue, no skips)
PR checks:       cancel-in-progress: true  (latest wins)
scheduled tasks: cancel-in-progress: false (no skips)

timeout-minutes: always set on every job
paths-ignore:    exclude docs/*.md to reduce unnecessary triggers
```

Concurrency config is a force multiplier for parallel dev workflows — get it wrong and your CI bills balloon; get it right and 5 instances push in harmony.

---
Building in public: https://my-web-app-b67f4.web.app/
#GitHubActions #CI #Flutter #buildinpublic #DevOps
