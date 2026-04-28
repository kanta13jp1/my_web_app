---
title: "GitHub Actions 高度活用 — reusable workflow / matrix / cache で CI を賢くする"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# GitHub Actions 高度活用 — reusable workflow / matrix / cache で CI を賢くする

GitHub Actions を「ただ CI を回すだけ」で使っている間は半分も活用できていない。実際に使っている高度パターンを公開する。

## 1. Reusable Workflow — 共通処理を再利用

複数ワークフローで同じステップを書いていたら、Reusable Workflow に切り出す:

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

呼び出し側:

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    uses: ./.github/workflows/reusable-flutter-setup.yml
    with:
      flutter-version: '3.27.0'
```

Before: 各ワークフローに `flutter pub get` 等を重複記述
After: 1ファイルに集約 → 更新が1箇所で済む

## 2. Matrix Strategy — 並行テスト

```yaml
jobs:
  test:
    strategy:
      matrix:
        platform: [vm, chrome]
        flutter-version: ['3.24.0', '3.27.0']
      fail-fast: false  # 1件失敗しても他を続ける

    runs-on: ubuntu-latest
    steps:
      - run: |
          if [ "${{ matrix.platform }}" = "chrome" ]; then
            flutter test --platform chrome
          else
            flutter test
          fi
```

4組 (2 platform × 2 version) を並行実行。`fail-fast: false` で全パターンの結果を確認できる。

## 3. Cache — 依存関係の高速化

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

`pubspec.lock` が変わらなければキャッシュをそのまま使う。CI 時間: 4分 → 1.5分。

## 4. Conditional Steps — 変更ファイルに応じた実行制御

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

`lib/` が変更されていなければ Flutter テストをスキップ。不要な CI 時間を削減。

## 5. Scheduled Tasks — $0 で定期実行

```yaml
on:
  schedule:
    - cron: '0 */4 * * *'  # 4時間毎
  workflow_dispatch:        # 手動実行も可能

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

GitHub Actions の無料枠 (月 2000分) で十分まかなえる。外部 cron サービス不要。

## 6. Concurrency Control — 並行実行の管理

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false  # 進行中をキャンセルしない (deploy-prod)
```

`cancel-in-progress: true` はプルリクエストの CI に使う (古いコミットのチェックをキャンセル)。
`cancel-in-progress: false` は本番デプロイに使う (途中キャンセルで中途半端な状態にしない)。

## うちのワークフロー一覧

```
ci.yml              - flutter test + analyze (push/PR)
deploy-prod.yml     - firebase hosting deploy (main push)
blog-publish.yml    - dev.to/Qiita 自動投稿 (workflow_dispatch)
cs-check.yml        - サポートチケット確認 (4時間毎)
daily-report.yml    - 日次レポート生成 (毎朝)
claude-agent-review.yml  - PR レビュー (PR open)
health-monitor.yml  - インフラヘルスチェック (30分毎)
```

7本のワークフローで開発・運用・コンテンツ投稿を自動化している。

## まとめ

GitHub Actions の高度活用は「Reusable → Matrix → Cache → Conditional → Schedule」の順に導入すると無理がない。特にキャッシュは効果が大きく、実装コストも低い。まずキャッシュから始める。
