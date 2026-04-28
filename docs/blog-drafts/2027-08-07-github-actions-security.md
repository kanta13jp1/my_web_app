---
title: "GitHub Actions セキュリティ強化 — secrets / OIDC / 最小権限の実践ガイド"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# GitHub Actions セキュリティ強化 — secrets / OIDC / 最小権限の実践ガイド

GHA を本番で使い続けると、セキュリティの落とし穴が見えてくる。個人開発で実際に踏んだミスと、対策をまとめる。

## よくある危険パターン

```yaml
# ❌ NG: secrets をログに出力してしまう
- run: echo "Token is ${{ secrets.API_TOKEN }}"

# ❌ NG: pull_request_target で外部 PR のコードを実行
on:
  pull_request_target:  # フォークからのコードが高権限で動く

# ❌ NG: 過大な権限
permissions:
  contents: write
  packages: write
  # 実際には read しか使わない
```

## Secrets の安全な管理

```yaml
# ✅ OK: env 経由で渡す (ログに出ない)
- name: Deploy
  env:
    API_TOKEN: ${{ secrets.API_TOKEN }}
  run: ./deploy.sh  # スクリプト内で $API_TOKEN を参照
```

**Repository Secrets vs Environment Secrets**:

```
Repository Secrets:   全 workflow からアクセス可能 (危険度高)
Environment Secrets:  特定 environment 限定 (production 環境のみ等)
```

```yaml
# Environment Secrets を使う
jobs:
  deploy:
    environment: production  # このジョブのみ production secrets を参照可
    steps:
      - run: echo ${{ secrets.PROD_KEY }}
```

## OIDC で長期トークンを廃止する

AWS / GCP / Azure では OIDC 認証を使うと、static credentials が不要になる:

```yaml
# ✅ AWS OIDC 認証 (static key不要)
jobs:
  deploy:
    permissions:
      id-token: write  # OIDC トークン取得に必要
      contents: read

    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789:role/github-actions-role
          aws-region: ap-northeast-1
          # ACCESS_KEY_ID / SECRET_ACCESS_KEY 不要！
```

```json
// AWS IAM Trust Policy (GitHub リポジトリを信頼)
{
  "Principal": {
    "Federated": "arn:aws:iam::123456789:oidc-provider/token.actions.githubusercontent.com"
  },
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:sub":
        "repo:myorg/myrepo:environment:production"
    }
  }
}
```

## 最小権限の原則

```yaml
# ✅ ジョブごとに必要な権限のみ付与
jobs:
  test:
    permissions:
      contents: read   # テストに必要な最小権限

  deploy:
    permissions:
      contents: read
      id-token: write  # OIDC のみ追加
```

```yaml
# ✅ デフォルト権限を read-only に制限
permissions:
  contents: read   # ワークフローレベルで絞る

jobs:
  release:
    permissions:
      contents: write  # このジョブだけ write に拡張
```

## Script Injection 防止

```yaml
# ❌ NG: GitHub context を直接 run に埋め込む
- run: echo "PR title: ${{ github.event.pull_request.title }}"
# PR タイトルに "; rm -rf /" が入ったら危険

# ✅ OK: env 経由で渡す (shell がエスケープする)
- env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "PR title: $PR_TITLE"
```

## 依存アクションのピン留め

```yaml
# ❌ NG: タグは書き換えられる可能性あり
- uses: actions/checkout@v4

# ✅ OK: コミットハッシュで固定 (書き換え不可)
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

## まとめ

```
優先順位:
  1. secrets は env 経由で渡す (ログ漏洩防止)
  2. permissions は最小権限 (ジョブ単位)
  3. OIDC で static key を廃止
  4. Script Injection: github.event.* は env 経由
  5. 依存アクションはハッシュでピン留め
```

GHA のセキュリティは「知らないと踏む」罠が多い。一度設定すれば後は自動で守ってくれる投資対効果の高い対策だ。
