---
title: "GitHub Actions Beyond the Basics: Reusable Workflows, Matrix, and Cache"
tags: ai,automation,indiedev,programming
published: true
---

# GitHub Actions Beyond the Basics: Reusable Workflows, Matrix, and Cache

Using GitHub Actions for "just running CI" misses half its value. Here are the advanced patterns I actually use in production.

## 1. Reusable Workflows — Share Common Steps

If multiple workflows repeat the same steps, extract them:

```yaml
# .github/workflows/reusable-flutter-setup.yml
on:
  workflow_call:
    inputs:
      flutter-version:
        required: false
        type: string
        default: '3.27.0'

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ inputs.flutter-version }}
          cache: true
      - run: flutter pub get
```

Caller:

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    uses: ./.github/workflows/reusable-flutter-setup.yml
    with:
      flutter-version: '3.27.0'
```

Before: `flutter pub get` duplicated across 5 workflows.
After: one file to update.

## 2. Matrix Strategy — Parallel Test Runs

```yaml
jobs:
  test:
    strategy:
      matrix:
        platform: [vm, chrome]
        flutter-version: ['3.24.0', '3.27.0']
      fail-fast: false  # don't stop on first failure

    runs-on: ubuntu-latest
    steps:
      - run: |
          if [ "${{ matrix.platform }}" = "chrome" ]; then
            flutter test --platform chrome
          else
            flutter test
          fi
```

4 combinations (2 platforms × 2 versions) run in parallel. `fail-fast: false` gives you the full result picture.

## 3. Cache — Speed Up Dependencies

```yaml
- name: Cache Flutter packages
  uses: actions/cache@v4
  with:
    path: |
      ~/.pub-cache
      .dart_tool
    key: flutter-${{ runner.os }}-${{ hashFiles('pubspec.lock') }}
    restore-keys: |
      flutter-${{ runner.os }}-

- name: Cache Deno dependencies
  uses: actions/cache@v4
  with:
    path: ~/.deno
    key: deno-${{ hashFiles('supabase/functions/**/deps.ts') }}
```

If `pubspec.lock` doesn't change, the cache is reused. CI time: 4min → 1.5min.

## 4. Conditional Steps — Run Only What Changed

```yaml
- name: Get changed files
  id: changes
  uses: dorny/paths-filter@v3
  with:
    filters: |
      flutter:
        - 'lib/**'
        - 'pubspec.yaml'
      supabase:
        - 'supabase/**'

- name: Run Flutter tests
  if: steps.changes.outputs.flutter == 'true'
  run: flutter test

- name: Deploy Edge Functions
  if: steps.changes.outputs.supabase == 'true'
  run: supabase functions deploy
```

Skip Flutter tests when only Supabase files changed. Cut unnecessary CI minutes.

## 5. Scheduled Tasks — $0 Recurring Jobs

```yaml
on:
  schedule:
    - cron: '0 */4 * * *'  # every 4 hours
  workflow_dispatch:         # also triggerable manually

jobs:
  digest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run digest
        env:
          SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
        run: |
          curl -sf "$SUPABASE_DIGEST_URL" \
            -H "Authorization: Bearer $SUPABASE_SERVICE_KEY"
```

GitHub Actions free tier (2000 min/month) covers it. No external cron service needed.

## 6. Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false  # don't cancel running deploys
```

- `cancel-in-progress: true` → for PR checks (cancel old commit's CI when new push arrives)
- `cancel-in-progress: false` → for production deploys (don't leave a half-deployed state)

## My Workflow Inventory

```
ci.yml              - flutter test + analyze (push/PR)
deploy-prod.yml     - firebase hosting deploy (main push)
blog-publish.yml    - dev.to/Qiita auto-publish (workflow_dispatch)
cs-check.yml        - support ticket check (every 4h)
daily-report.yml    - daily report generation (every morning)
claude-agent-review.yml  - PR review (PR open)
health-monitor.yml  - infra health check (every 30min)
```

7 workflows automate dev, ops, and content publishing.

## Summary

Introduce GitHub Actions features in this order: Reusable → Matrix → Cache → Conditional → Schedule. Cache has the highest impact for the lowest implementation cost. Start there.
