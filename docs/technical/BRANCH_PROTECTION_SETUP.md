# ブランチ保護設定ガイド

GitHub の `main` / `staging` / `develop` ブランチに対するブランチ保護ルールの設定手順。

---

## 保護対象ブランチ

| ブランチ | 保護レベル | 用途 |
| --- | --- | --- |
| `main` | 高 (PR必須 + CI必須) | 本番環境 (Firebase Hosting prod) |
| `staging` | 中 (PR必須) | ステージング環境 |
| `develop` | 低 (CI推奨) | 開発用統合ブランチ |

---

## main ブランチの保護ルール設定手順

### GitHub リポジトリ設定

1. リポジトリの **Settings** → **Branches** に移動
2. **Add branch protection rule** をクリック
3. **Branch name pattern**: `main` を入力

### 有効にする設定

```
✅ Require a pull request before merging
   ✅ Require approvals: 0 (個人プロジェクトのため省略可)
   ✅ Dismiss stale pull request approvals when new commits are pushed

✅ Require status checks to pass before merging
   ✅ Require branches to be up to date before merging
   Status checks (必須):
     - lint-and-test
     - security-check
     - build-matrix

✅ Require conversation resolution before merging

✅ Do not allow bypassing the above settings
```

### 無効にする設定 (個人プロジェクト)

```
☐ Require signed commits      (GPG署名は任意)
☐ Require linear history      (マージコミット許可)
☐ Lock branch                 (メンテナンス時のみ有効化)
```

---

## staging ブランチの保護ルール

```
✅ Require a pull request before merging
✅ Require status checks: lint-and-test
☐ Require approvals
```

---

## CI チェック連携

ブランチ保護で参照する status checks は `.github/workflows/ci.yml` が定義:

| Status Check | ワークフロー | 内容 |
| --- | --- | --- |
| `lint-and-test` | `ci.yml` | flutter analyze + deno lint |
| `security-check` | `ci.yml` | 認証ファイル検出・シークレットスキャン |
| `build-matrix` | `ci.yml` | Flutter Web ビルド確認 |

> **注意**: GitHub Actions の status check 名は `ci.yml` の `jobs.<job_id>.name` に対応する。
> ワークフローを変更した場合はブランチ保護の status checks も更新すること。

---

## Claude Code Schedule との関係

`cs-check` Schedule タスクは毎時 :07 に PR レビューを実施する。
ブランチ保護が有効なため、直接 push を行う Scheduleタスクは `main` ブランチへの bypass を
リポジトリ設定の **Allow specified actors to bypass required pull requests** で許可する必要がある
（または `workflow_dispatch` 経由のみ許可）。

---

## 関連ドキュメント

- [CI/CD Setup Guide](../CICD_SETUP_GUIDE.md)
- [CI/CD Pipeline Guide](./CI_CD_GUIDE.md)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
