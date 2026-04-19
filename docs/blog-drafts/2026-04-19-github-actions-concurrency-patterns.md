---
title: "GitHub Actions Concurrencyの設計パターン — cancel-in-progress: false で並行プッシュを捌く"
tags: GitHubActions,CI/CD,Flutter,個人開発,buildinpublic
published: true
---

# GitHub Actions Concurrencyの設計パターン

## 問題: 複数インスタンスが同時プッシュすると何が起きるか

5つのClaude Codeインスタンスが並行して開発すると、mainブランチへのpushが短時間に集中する。

デフォルト設定だと:
- deployワークフローが5本同時起動
- リソースを食い合ってタイムアウト
- 古いdeployが新しいコードを上書きする可能性

## `cancel-in-progress: false` が正解

```yaml
# .github/workflows/deploy-prod.yml
concurrency:
  group: deploy-prod
  cancel-in-progress: false  # ← キュー方式
```

`cancel-in-progress: true` は **CI用** (古いPRビルドをキャンセルしたい場合)。
`cancel-in-progress: false` は **deploy用** (順番に全部実行したい場合)。

| 用途 | cancel-in-progress |
|------|-------------------|
| CI (PR ビルド) | `true` — 古いPRビルドは不要 |
| deploy-prod | `false` — 全コミットをデプロイ |
| blog-publish | `false` — 全投稿を実行 |
| schedule | `false` — 定期タスクをスキップしない |

## concurrency.group の設計

```yaml
# ❌ 全ワークフローで同じグループ名 → 互いにブロック
concurrency:
  group: ci

# ✅ ワークフロー名で分離
concurrency:
  group: ${{ github.workflow }}
  cancel-in-progress: false

# ✅ PR単位でCI競合を避ける
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # 同じPRの古いビルドはキャンセル
```

## 実例: 5インスタンス並行 deploy の設定

```yaml
# deploy-prod.yml
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

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to Firebase
        run: firebase deploy --only hosting
```

## timeout-minutes の適正値

各ジョブに `timeout-minutes` を設定しないと、ハングしたジョブが6時間走り続ける:

```yaml
jobs:
  build:
    timeout-minutes: 20  # Flutter Web ビルドは通常10-15分
  deploy:
    timeout-minutes: 10  # Firebase deploy は通常3-5分
  lint:
    timeout-minutes: 5   # flutter analyze は通常2分
```

## paths-ignore で不要トリガーを削減

```yaml
on:
  push:
    branches: [main]
    paths-ignore:
      - 'docs/**'
      - '**.md'
      - '.claude/**'
```

ドキュメント変更でdeployが走らないようにする。

## まとめ

```
deploy → cancel-in-progress: false (キュー)
CI/PR → cancel-in-progress: true  (最新優先)
schedule → cancel-in-progress: false (スキップなし)

timeout-minutes → 全ジョブに必ず設定
paths-ignore → docs/*.md は除外推奨
```

5インスタンス並行開発では concurrency 設計が CI コストと安定性を左右する。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#GitHubActions #CI/CD #Flutter #buildinpublic #個人開発
