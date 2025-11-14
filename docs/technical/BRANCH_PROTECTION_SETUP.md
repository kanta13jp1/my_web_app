# Branch Protection Rules Setup Guide

このドキュメントでは、GitHubリポジトリのブランチ保護ルールの設定手順を説明します。

## 📋 目次

1. [ブランチ保護ルール概要](#ブランチ保護ルール概要)
2. [設定手順](#設定手順)
3. [main ブランチの保護設定](#main-ブランチの保護設定)
4. [staging ブランチの保護設定](#staging-ブランチの保護設定)
5. [develop ブランチの保護設定](#develop-ブランチの保護設定)
6. [検証方法](#検証方法)

## ブランチ保護ルール概要

ブランチ保護ルールは、重要なブランチへの直接pushを防ぎ、コードの品質を保つために設定します。

### 各ブランチの保護レベル

| ブランチ | 保護レベル | 理由 |
|---------|-----------|------|
| `main` | 最高 | 本番環境に直結 |
| `staging` | 高 | 本番前の最終確認環境 |
| `develop` | 中 | 開発統合ブランチ |

## 設定手順

### 前提条件

- リポジトリのAdmin権限が必要です
- GitHubの有料プランまたはパブリックリポジトリが必要です（一部機能）

### 基本的な設定手順

1. GitHubリポジトリページにアクセス
2. `Settings` タブをクリック
3. 左サイドバーの `Branches` をクリック
4. `Branch protection rules` セクションで `Add rule` をクリック

## main ブランチの保護設定

本番環境に直結するため、最も厳格な保護設定を行います。

### 設定項目

#### 1. Branch name pattern

```
main
```

#### 2. Protect matching branches

以下の項目にチェックを入れます:

##### ✅ Require a pull request before merging

- **説明**: マージ前にPRを必須にする
- **サブオプション**:
  - ✅ **Require approvals**: 最低承認数を `1` に設定
  - ✅ **Dismiss stale pull request approvals when new commits are pushed**: 新しいコミットがpushされたら承認を無効化
  - ✅ **Require review from Code Owners**: Code Ownersのレビューを必須（オプション）

##### ✅ Require status checks to pass before merging

- **説明**: CIチェックが通過していることを必須にする
- **サブオプション**:
  - ✅ **Require branches to be up to date before merging**: マージ前にブランチを最新化
- **必要なStatus checks**:
  ```
  lint-and-test
  security-check
  build-matrix
  ```

##### ✅ Require conversation resolution before merging

- **説明**: すべてのレビューコメントが解決済みであることを必須にする

##### ✅ Require signed commits (推奨)

- **説明**: 署名付きコミットを必須にする
- **注意**: チーム全員がGPG署名を設定する必要があります

##### ✅ Require linear history (オプション)

- **説明**: マージコミットを禁止し、リニアな履歴を保つ
- **注意**: `git merge --no-ff` が使えなくなります

##### ✅ Include administrators

- **説明**: 管理者にもこれらのルールを適用する
- **重要**: セキュリティのため必ず有効にしてください

##### ✅ Restrict who can push to matching branches (オプション)

- **説明**: 特定のユーザー/チームのみpushを許可
- **設定**: CI/CDボットなど必要な場合のみ

##### ✅ Allow force pushes

- **説明**: force pushを許可
- **設定**: ❌ **無効** (絶対に有効にしないでください)

##### ✅ Allow deletions

- **説明**: ブランチの削除を許可
- **設定**: ❌ **無効** (mainブランチは削除不可)

### 設定スクリーンショット

```
Branch name pattern: main

[✓] Require a pull request before merging
    [✓] Require approvals (1)
    [✓] Dismiss stale pull request approvals when new commits are pushed
    [ ] Require review from Code Owners

[✓] Require status checks to pass before merging
    [✓] Require branches to be up to date before merging
    Status checks that are required:
    ✓ lint-and-test
    ✓ security-check
    ✓ build-matrix

[✓] Require conversation resolution before merging
[ ] Require signed commits
[ ] Require linear history
[✓] Include administrators
[ ] Restrict who can push to matching branches
[ ] Allow force pushes
[ ] Allow deletions
```

### 保存

最後に `Create` または `Save changes` ボタンをクリックして保存します。

## staging ブランチの保護設定

ステージング環境用の保護設定です。mainブランチより少し緩めの設定にします。

### 設定項目

#### 1. Branch name pattern

```
staging
```

#### 2. Protect matching branches

##### ✅ Require a pull request before merging

- **サブオプション**:
  - ✅ **Require approvals**: 最低承認数を `1` に設定
  - ❌ **Dismiss stale pull request approvals when new commits are pushed**: 無効でも可

##### ✅ Require status checks to pass before merging

- **サブオプション**:
  - ✅ **Require branches to be up to date before merging**
- **必要なStatus checks**:
  ```
  lint-and-test
  security-check
  build-matrix
  ```

##### ✅ Require conversation resolution before merging

##### ✅ Include administrators

##### ❌ Allow force pushes: 無効

##### ❌ Allow deletions: 無効

### 設定スクリーンショット

```
Branch name pattern: staging

[✓] Require a pull request before merging
    [✓] Require approvals (1)
    [ ] Dismiss stale pull request approvals when new commits are pushed

[✓] Require status checks to pass before merging
    [✓] Require branches to be up to date before merging
    Status checks that are required:
    ✓ lint-and-test
    ✓ security-check
    ✓ build-matrix

[✓] Require conversation resolution before merging
[✓] Include administrators
[ ] Allow force pushes
[ ] Allow deletions
```

## develop ブランチの保護設定

開発環境用の保護設定です。開発の柔軟性を保ちつつ、最低限の品質を保証します。

### 設定項目

#### 1. Branch name pattern

```
develop
```

#### 2. Protect matching branches

##### ✅ Require a pull request before merging

- **サブオプション**:
  - ❌ **Require approvals**: レビューは推奨だが必須ではない（チームの方針による）

##### ✅ Require status checks to pass before merging

- **サブオプション**:
  - ❌ **Require branches to be up to date before merging**: 無効でも可（開発速度優先）
- **必要なStatus checks**:
  ```
  lint-and-test
  ```

##### ❌ Require conversation resolution before merging: 無効でも可

##### ✅ Include administrators

##### ❌ Allow force pushes: 無効

##### ❌ Allow deletions: 無効

### 設定スクリーンショット

```
Branch name pattern: develop

[✓] Require a pull request before merging
    [ ] Require approvals

[✓] Require status checks to pass before merging
    [ ] Require branches to be up to date before merging
    Status checks that are required:
    ✓ lint-and-test

[ ] Require conversation resolution before merging
[✓] Include administrators
[ ] Allow force pushes
[ ] Allow deletions
```

## 検証方法

ブランチ保護ルールが正しく設定されているか確認します。

### 1. 直接pushのテスト

```bash
# mainブランチに直接pushを試みる（失敗すべき）
git checkout main
git commit --allow-empty -m "Test commit"
git push origin main
```

**期待される結果**:
```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: error: Changes must be made through a pull request.
```

### 2. PRなしでのマージテスト

GitHub UI上で、PRを作成せずに直接マージを試みます。

**期待される結果**: マージボタンが表示されない、またはエラーメッセージが表示される

### 3. CIチェック未通過でのマージテスト

1. feature ブランチを作成
2. わざとLintエラーを含むコードをコミット
3. PRを作成
4. CIが失敗することを確認
5. マージを試みる

**期待される結果**: "All checks have passed" が表示されるまでマージボタンが無効

### 4. レビュー承認なしでのマージテスト

1. PRを作成
2. レビュー承認を得ずにマージを試みる

**期待される結果**: "This branch requires approvals" というメッセージが表示され、マージできない

## トラブルシューティング

### Status checksが表示されない

**症状**: "Require status checks to pass" を有効にしたが、Status checksの一覧が表示されない

**解決方法**:
1. 一度CIワークフローを実行する（PRを作成するなど）
2. ワークフローが実行されると、Status checks一覧に表示されるようになります
3. ブランチ保護ルール設定画面を再読み込み

### ブランチ保護ルールが適用されない

**症状**: ルールを設定したのに、直接pushできてしまう

**確認事項**:
1. **Branch name pattern** が正しいか確認
2. **Include administrators** が有効になっているか確認
3. リポジトリのSettingsで権限を確認

### 緊急時にブランチ保護を一時的に無効化したい

**手順**:
1. `Settings` → `Branches` → 該当のルールを開く
2. 一時的に無効化したいオプションのチェックを外す
3. 緊急対応後、必ず元に戻す

⚠️ **警告**: 本番ブランチの保護を外すのは最終手段です。

## GitHub CLI を使った設定（上級者向け）

GitHub CLIを使ってブランチ保護ルールを設定できます。

### インストール

```bash
# macOS
brew install gh

# Windows
winget install GitHub.cli

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
```

### 認証

```bash
gh auth login
```

### main ブランチの保護設定

```bash
gh api repos/kanta13jp1/my_web_app/branches/main/protection \
  --method PUT \
  --field required_status_checks='{"strict":true,"contexts":["lint-and-test","security-check","build-matrix"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  --field restrictions=null
```

### 設定の確認

```bash
gh api repos/kanta13jp1/my_web_app/branches/main/protection
```

## ベストプラクティス

### 1. 段階的な導入

いきなり厳格なルールを適用するのではなく、段階的に導入します:

1. **Phase 1**: PR必須のみ
2. **Phase 2**: CIチェック必須を追加
3. **Phase 3**: レビュー承認必須を追加
4. **Phase 4**: その他の細かいルールを追加

### 2. チーム全体での合意

ブランチ保護ルールはチーム全体に影響します。設定前にチーム内で合意を得てください。

### 3. ドキュメント化

設定したルールをドキュメント化し、チーム全員がアクセスできるようにします（このドキュメントなど）。

### 4. 定期的な見直し

プロジェクトの成長に合わせて、ブランチ保護ルールを見直します。

## 関連ドキュメント

- [CI_CD_GUIDE.md](./CI_CD_GUIDE.md) - CI/CDパイプライン概要
- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - デプロイ手順
- [CONTRIBUTING.md](../CONTRIBUTING.md) - コントリビューションガイド

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025-11-14 | 1.0.0 | 初版作成 |
