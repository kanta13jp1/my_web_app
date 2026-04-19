---
title: "cancel-in-progress:trueでデプロイが消えた — GitHub Actions concurrency の落とし穴"
tags: GitHubActions,CI/CD,Flutter,個人開発,buildinpublic
published: true
---

# cancel-in-progress:trueでデプロイが消えた

## 症状: 並行 push で後発 commit がデプロイされない

```
Commit A → push → deploy-prod starts
Commit B → push → deploy-prod starts → A's run gets CANCELLED
                                        ↑ A が消える
```

複数インスタンス (VSCode版/PS版/Win版) が並行で push していると、
後から来た commit が前の commit のデプロイをキャンセルしてしまう。

結果: **Commit A の変更が本番に反映されない**。

## 原因: `cancel-in-progress: true` の誤用

```yaml
# ❌ 問題のある設定
concurrency:
  group: deploy-prod
  cancel-in-progress: true  # 実行中のジョブをキャンセル
```

`cancel-in-progress: true` は「同じグループの実行中ジョブをキャンセルする」設定。
CI系 (lint/test) では有効だが、**デプロイ系では危険**。

## 修正: `cancel-in-progress: false` に変更

```yaml
# ✅ 安全な設定
concurrency:
  group: deploy-prod
  cancel-in-progress: false  # 先行ジョブの完了を待ってから実行
```

`false` にすると後発ジョブは先行ジョブの完了を待機してから実行される。
全ての commit が順次デプロイされる。

## ユースケース別の推奨設定

| WF種別 | cancel-in-progress | 理由 |
|--------|-------------------|------|
| CI (lint/test) | `true` | 最新 commit だけテストすれば十分 |
| **deploy (prod/staging)** | **`false`** | **全 commit をデプロイする必要がある** |
| blog-publish | `true` | 重複投稿防止 |
| daily-report | `true` | 最新データだけ必要 |

## 待機時間の見積もり

`cancel-in-progress: false` にすると後発ジョブは待機する:

```
実行時間 11分 × 並行数 = 最大待機時間
例: 3インスタンスが同時 push → 最大 22 分待機 (3本目の場合)
```

5インスタンス体制でも deploy は順番に実行されるため、
**本番への反映漏れはゼロ**になる。

## 実際の修正

```yaml
# .github/workflows/deploy-prod.yml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false  # ← true から false に変更
```

`group` に `github.ref` を含めることで、
異なるブランチへの push は別グループとして並行実行される。

## まとめ

- **CI系** → `cancel-in-progress: true` (高速フィードバック)
- **Deploy系** → `cancel-in-progress: false` (デプロイ漏れ防止)

GitHub Actions を使い始めたときはデフォルトの `true` をそのまま使いがち。
マルチインスタンス開発になったタイミングで必ず確認すべき設定。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#GitHubActions #CI/CD #buildinpublic #個人開発
