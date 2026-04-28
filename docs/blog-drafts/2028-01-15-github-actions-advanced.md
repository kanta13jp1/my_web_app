---
title: "GitHub Actions 高度活用パターン — Matrix / Cache / Reusable Workflows"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# GitHub Actions 高度活用パターン — Matrix / Cache / Reusable Workflows

基本の push → deploy を超えた GHA 活用法。実行時間短縮・再利用・並列化の 3 テーマを整理する。

## Matrix: 並列テストで CI を高速化

```yaml
# 複数 OS / Flutter バージョンで並列テスト
jobs:
  test:
    strategy:
      fail-fast: false  # 1つ失敗しても他を継続
      matrix:
        os: [ubuntu-latest, macos-latest]
        flutter: ['3.19.0', '3.22.0']
        exclude:
          - os: macos-latest
            flutter: '3.19.0'  # 特定の組み合わせを除外

    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: ${{ matrix.flutter }}
      - run: flutter test
```

**動的 Matrix** (JSON で制御):

```yaml
jobs:
  setup:
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - id: set-matrix
        run: |
          echo 'matrix={"include":[{"env":"staging"},{"env":"prod"}]}' >> $GITHUB_OUTPUT

  deploy:
    needs: setup
    strategy:
      matrix: ${{ fromJson(needs.setup.outputs.matrix) }}
    steps:
      - run: echo "Deploying to ${{ matrix.env }}"
```

## Cache: 依存関係をキャッシュして高速化

```yaml
steps:
  - uses: actions/checkout@v4

  # Flutter SDK キャッシュ
  - uses: subosito/flutter-action@v2
    with:
      flutter-version: '3.22.0'
      cache: true  # pub cache + Flutter SDK を自動キャッシュ

  # pub get のキャッシュ (手動制御したい場合)
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

**キャッシュ効果の例**:

```
キャッシュなし: flutter pub get → 45秒
キャッシュあり: flutter pub get → 3秒 (93% 短縮)

CI 全体: 5分 → 2分
```

## Reusable Workflows: 再利用可能なワークフロー

```yaml
# .github/workflows/flutter-ci.yml (呼び出される側)
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
# .github/workflows/deploy.yml (呼び出す側)
jobs:
  build-and-test:
    uses: ./.github/workflows/flutter-ci.yml
    with:
      flutter-version: '3.22.0'
      run-tests: true
    secrets:
      SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
```

## Composite Actions: 手順を再利用可能ステップに抽出

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

# 使い方 (任意の workflow から)
steps:
  - uses: ./.github/actions/setup-flutter
    with:
      flutter-version: '3.22.0'
```

## Artifacts: ビルド成果物の受け渡し

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

## まとめ

```
Matrix           → OS/バージョン並列テストで品質向上 + 実行時間短縮
Cache            → pub get を 45s→3s (93% 短縮)
Reusable WF      → 複数リポジトリで同じ CI を共有
Composite Action → 複数 workflow で共通ステップを再利用
Artifacts        → ジョブ間でビルド成果物を受け渡し
```

GHA の実行コスト (GitHub Free: 2,000分/月) を意識しながら、キャッシュと並列化で効率化する。

