---
title: "GitHub Actions Advanced Patterns: Matrix, Cache, and Reusable Workflows"
tags: ai,indiedev,automation,buildinpublic
published: true
---

# GitHub Actions Advanced Patterns: Matrix, Cache, and Reusable Workflows

Beyond the basic push-to-deploy. Three patterns to speed up CI, reduce duplication, and parallelize builds.

## Matrix: Parallel Tests Across Configs

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        flutter: ['3.19.0', '3.22.0']
        exclude:
          - os: macos-latest
            flutter: '3.19.0'

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ matrix.flutter }}
      - run: flutter test
```

**Dynamic matrix from JSON output**:

```yaml
jobs:
  setup:
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - id: set-matrix
        run: |
          echo 'matrix={"include":[{"env":"staging"},{"env":"prod"}]}' \
            >> $GITHUB_OUTPUT

  deploy:
    needs: setup
    strategy:
      matrix: ${{ fromJson(needs.setup.outputs.matrix) }}
    steps:
      - run: echo "Deploying to ${{ matrix.env }}"
```

## Cache: Cut Dependency Install Time

```yaml
steps:
  - uses: actions/checkout@v4

  # subosito/flutter-action built-in cache
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: '3.22.0'
      cache: true

  # Manual control if you need it
  - uses: actions/cache@v4
    with:
      path: |
        ~/.pub-cache
        .dart_tool
      key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}
      restore-keys: |
        ${{ runner.os }}-pub-

  - run: flutter pub get
  - run: flutter test
```

**Real-world impact**:

```
No cache:    flutter pub get → 45s
With cache:  flutter pub get → 3s  (93% faster)
Full CI run: 5min → 2min
```

## Reusable Workflows: Share CI Logic

```yaml
# .github/workflows/flutter-ci.yml (called workflow)
on:
  workflow_call:
    inputs:
      flutter-version:
        required: false
        type: string
        default: '3.22.0'
      run-tests:
        required: false
        type: boolean
        default: true
    secrets:
      SUPABASE_URL:
        required: true

jobs:
  ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ inputs.flutter-version }}
          cache: true
      - run: flutter pub get
      - if: ${{ inputs.run-tests }}
        run: flutter test
      - run: flutter build web --release
```

```yaml
# .github/workflows/deploy.yml (caller)
jobs:
  build-and-test:
    uses: ./.github/workflows/flutter-ci.yml
    with:
      flutter-version: '3.22.0'
      run-tests: true
    secrets:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
```

## Composite Actions: Extract Reusable Steps

```yaml
# .github/actions/setup-flutter/action.yml
name: 'Setup Flutter'
inputs:
  flutter-version:
    default: '3.22.0'
runs:
  using: composite
  steps:
    - uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ inputs.flutter-version }}
        cache: true
    - run: flutter pub get
      shell: bash

# Usage in any workflow
steps:
  - uses: ./.github/actions/setup-flutter
    with:
      flutter-version: '3.22.0'
```

## Artifacts: Pass Build Outputs Between Jobs

```yaml
jobs:
  build:
    steps:
      - run: flutter build web --release
      - uses: actions/upload-artifact@v4
        with:
          name: web-build
          path: build/web/
          retention-days: 7

  deploy:
    needs: build
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: web-build
          path: build/web/
      - run: firebase deploy --only hosting
```

## Summary

```
Matrix           → parallel OS/version tests — faster + better coverage
Cache            → pub get 45s → 3s (93% faster)
Reusable WF      → share CI logic across repos
Composite Action → shared steps inside a repo
Artifacts        → hand build output between jobs cleanly
```

GitHub Free includes 2,000 minutes/month. Cache + parallelization keeps you well within that.

