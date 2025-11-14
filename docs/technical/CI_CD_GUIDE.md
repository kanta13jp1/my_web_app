# CI/CD Pipeline Guide

このドキュメントでは、プロジェクトのCI/CDパイプラインの概要、ブランチ戦略、開発フローについて説明します。

## 📋 目次

1. [概要](#概要)
2. [ブランチ戦略](#ブランチ戦略)
3. [開発フロー](#開発フロー)
4. [GitHub Actions ワークフロー](#github-actions-ワークフロー)
5. [環境別デプロイ](#環境別デプロイ)
6. [トラブルシューティング](#トラブルシューティング)

## 概要

本プロジェクトでは、Git Flowに基づいたブランチ戦略とGitHub Actionsを使用したCI/CDパイプラインを採用しています。

### アーキテクチャ概要

```
┌─────────────────────────────────────────────────────────────┐
│                      開発者                                  │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─ feature/* ブランチで開発
                  ├─ develop へPR作成
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                   GitHub Actions                             │
│  ┌─────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   CI Check  │  │  Build Test  │  │  Security    │       │
│  └─────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ├─ develop → 開発環境デプロイ
                  ├─ staging → ステージング環境デプロイ
                  ├─ main → 本番環境デプロイ
                  │
┌─────────────────▼───────────────────────────────────────────┐
│              デプロイ先環境                                  │
│  ┌───────────┐  ┌─────────────┐  ┌───────────────┐         │
│  │   Dev     │  │  Staging    │  │  Production   │         │
│  │ Firebase  │  │  Firebase   │  │   Firebase    │         │
│  │ Supabase  │  │  Supabase   │  │   Supabase    │         │
│  └───────────┘  └─────────────┘  └───────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## ブランチ戦略

本プロジェクトはGit Flowをベースとしたブランチ戦略を採用しています。

### ブランチ構成

```
main (本番環境)
├── staging (ステージング環境)
│   └── develop (開発環境)
│       ├── feature/xxx (機能開発)
│       ├── bugfix/xxx (バグ修正)
│       └── hotfix/xxx (緊急修正)
```

### ブランチ詳細

#### 1. `main` ブランチ
- **用途**: 本番環境
- **保護設定**:
  - 直接pushは禁止
  - PR必須
  - レビュー必須（最低1名）
  - CIチェック必須
- **デプロイ**: 自動（Firebase Hosting + Supabase）
- **命名規則**: `main`

#### 2. `staging` ブランチ
- **用途**: ステージング環境（本番前の最終確認）
- **保護設定**:
  - PR必須（developブランチからのみ）
  - CIチェック必須
- **デプロイ**: 自動
- **命名規則**: `staging`

#### 3. `develop` ブランチ
- **用途**: 開発環境（開発中の機能を統合）
- **保護設定**:
  - PR必須（feature/bugfixブランチからのみ）
  - CIチェック必須
- **デプロイ**: 自動
- **命名規則**: `develop`

#### 4. `feature/*` ブランチ
- **用途**: 新機能開発
- **作成元**: `develop`
- **マージ先**: `develop`
- **命名規則**: `feature/機能名` (例: `feature/user-authentication`)
- **ライフサイクル**: マージ後削除

#### 5. `bugfix/*` ブランチ
- **用途**: バグ修正
- **作成元**: `develop`
- **マージ先**: `develop`
- **命名規則**: `bugfix/バグ名` (例: `bugfix/login-error`)
- **ライフサイクル**: マージ後削除

#### 6. `hotfix/*` ブランチ
- **用途**: 本番環境の緊急修正
- **作成元**: `main`
- **マージ先**: `main` + `develop` (両方にマージ)
- **命名規則**: `hotfix/修正内容` (例: `hotfix/critical-security-patch`)
- **ライフサイクル**: マージ後削除

## 開発フロー

### 標準的な開発フロー

```
1. GitHub Issueを作成
   ↓
2. feature/bugfix ブランチを作成
   ↓
3. コードを実装
   ↓
4. ローカルでテスト
   ↓
5. commitとpush
   ↓
6. developブランチへPR作成
   ↓
7. CI自動実行 (Lint, Test, Build)
   ↓
8. コードレビュー
   ↓
9. developへマージ → 開発環境に自動デプロイ
   ↓
10. 開発環境で動作確認
   ↓
11. stagingへPR → レビュー → マージ → ステージング環境に自動デプロイ
   ↓
12. ステージング環境で最終確認
   ↓
13. mainへPR → レビュー → マージ → 本番環境に自動デプロイ
```

### コマンド例

#### 1. 新機能開発の開始

```bash
# developブランチを最新化
git checkout develop
git pull origin develop

# feature ブランチを作成
git checkout -b feature/user-profile

# 開発作業...

# 変更をコミット
git add .
git commit -m "feat: Add user profile page"

# リモートにプッシュ
git push -u origin feature/user-profile

# GitHub上でPRを作成
# https://github.com/kanta13jp1/my_web_app/compare/develop...feature/user-profile
```

#### 2. バグ修正

```bash
# developブランチから bugfix ブランチを作成
git checkout develop
git pull origin develop
git checkout -b bugfix/fix-login-error

# 修正作業...

git add .
git commit -m "fix: Resolve login authentication error"
git push -u origin bugfix/fix-login-error

# PRを作成してdevelopにマージ
```

#### 3. 緊急本番修正 (Hotfix)

```bash
# mainブランチから hotfix ブランチを作成
git checkout main
git pull origin main
git checkout -b hotfix/security-patch

# 修正作業...

git add .
git commit -m "hotfix: Apply critical security patch"
git push -u origin hotfix/security-patch

# mainとdevelopの両方にPRを作成
```

## GitHub Actions ワークフロー

### ワークフロー一覧

| ワークフロー | トリガー | 実行内容 |
|------------|---------|---------|
| **CI** | すべてのPR | Lint, Test, Build, Security Check |
| **Deploy to Development** | `develop` へのpush | CI + Supabase Migration + Deploy |
| **Deploy to Staging** | `staging` へのpush | CI + Supabase Migration + Deploy |
| **Deploy to Production** | `main` へのpush | CI + Supabase Migration + Deploy + Release Tag |

### CI ワークフロー詳細

**ファイル**: `.github/workflows/ci.yml`

**実行内容**:
1. Flutter環境セットアップ
2. 依存関係インストール (`flutter pub get`)
3. Lintチェック (`flutter analyze`)
4. フォーマットチェック (`dart format`)
5. テスト実行 (`flutter test`)
6. ビルドテスト (`flutter build web`)
7. セキュリティチェック（機密ファイル、ハードコードされたシークレット）

**成功条件**: すべてのステップが成功

### デプロイワークフロー詳細

#### Development (開発環境)

**ファイル**: `.github/workflows/deploy-dev.yml`

**トリガー**: `develop` ブランチへのpush

**実行内容**:
1. CI チェック実行
2. Supabase マイグレーション（開発環境）
3. Flutter Web ビルド（開発設定）
4. Firebase Hosting デプロイ（devチャネル）
5. Slack通知

#### Staging (ステージング環境)

**ファイル**: `.github/workflows/deploy-staging.yml`

**トリガー**: `staging` ブランチへのpush

**実行内容**:
1. CI チェック実行
2. Supabase マイグレーション（ステージング環境）
3. Flutter Web ビルド（ステージング設定）
4. Firebase Hosting デプロイ（stagingチャネル）
5. Slack通知

#### Production (本番環境)

**ファイル**: `.github/workflows/deploy-prod.yml`

**トリガー**: `main` ブランチへのpush

**実行内容**:
1. CI チェック実行
2. バージョン生成（自動インクリメント）
3. Supabase マイグレーション（本番環境）
4. Flutter Web ビルド（本番設定、最適化）
5. Firebase Hosting デプロイ（liveチャネル）
6. Git リリースタグ作成
7. GitHub Release作成
8. Slack通知

## 環境別デプロイ

### 環境一覧

| 環境 | ブランチ | URL | 用途 |
|------|---------|-----|------|
| Development | `develop` | https://dev.your-app.web.app | 開発中の機能テスト |
| Staging | `staging` | https://staging.your-app.web.app | 本番前の最終確認 |
| Production | `main` | https://your-app.web.app | 本番環境 |

### デプロイプロセス

#### 自動デプロイ

```
Push to develop/staging/main
  ↓
CI Checks (Lint, Test, Build)
  ↓
Supabase Migration
  ↓
Flutter Build
  ↓
Firebase Deploy
  ↓
Slack Notification
```

#### 手動デプロイ

緊急時やCI/CDパイプラインが利用できない場合の手動デプロイ方法については、[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)を参照してください。

## トラブルシューティング

### よくある問題と解決方法

#### 1. CI チェックが失敗する

**症状**: PRを作成したがCIチェックが失敗する

**解決方法**:

```bash
# ローカルでLintチェック
flutter analyze

# ローカルでフォーマットチェック
dart format --set-exit-if-changed .

# ローカルでテスト実行
flutter test

# ローカルでビルドテスト
flutter build web --release
```

すべてのチェックが通ることを確認してから再度pushしてください。

#### 2. Supabase マイグレーションが失敗する

**症状**: デプロイ時にSupabaseマイグレーションでエラーが発生する

**解決方法**:

1. ローカルでマイグレーションをテスト:
   ```bash
   supabase db push --dry-run
   ```

2. マイグレーションファイルの構文チェック

3. GitHub Secretsの確認:
   - `SUPABASE_ACCESS_TOKEN`
   - `SUPABASE_PROJECT_ID_*`
   - `SUPABASE_DB_PASSWORD_*`

#### 3. Firebase デプロイが失敗する

**症状**: Firebase Hostingへのデプロイでエラーが発生する

**解決方法**:

1. GitHub Secretsの確認:
   - `FIREBASE_SERVICE_ACCOUNT_*`
   - `FIREBASE_PROJECT_ID`

2. Firebaseプロジェクトの権限確認

3. ローカルでデプロイをテスト:
   ```bash
   firebase deploy --only hosting --debug
   ```

#### 4. ビルドサイズが大きすぎる

**症状**: ビルド後のファイルサイズが大きい

**解決方法**:

1. 不要な依存関係を削除:
   ```bash
   flutter pub deps
   ```

2. ビルド最適化オプションを使用:
   ```bash
   flutter build web --release --tree-shake-icons
   ```

3. assetsの最適化（画像圧縮など）

#### 5. 環境変数が反映されない

**症状**: デプロイ後に環境変数の値が正しくない

**解決方法**:

1. GitHub Secretsの設定を確認

2. ワークフローファイルの環境変数設定を確認

3. `.env.example`と実際の設定を比較

## ベストプラクティス

### コミットメッセージ

Conventional Commitsに従ってコミットメッセージを記述してください:

```
<type>: <subject>

<body>

<footer>
```

**タイプ**:
- `feat`: 新機能
- `fix`: バグ修正
- `docs`: ドキュメント変更
- `style`: フォーマット変更
- `refactor`: リファクタリング
- `test`: テスト追加・修正
- `chore`: ビルドプロセスやツールの変更

**例**:
```
feat: Add user authentication feature

Implement login/logout functionality using Supabase Auth.
Includes email verification and password reset.

Closes #123
```

### PR作成時のチェックリスト

- [ ] ローカルでCIチェックを実行済み
- [ ] 関連Issueをリンク
- [ ] 変更内容を明確に記載
- [ ] テストを追加/更新
- [ ] ドキュメントを更新
- [ ] スクリーンショットを添付（UI変更時）

### コードレビュー時のチェックポイント

- [ ] コードの可読性
- [ ] パフォーマンスへの影響
- [ ] セキュリティ上の問題
- [ ] テストの網羅性
- [ ] ドキュメントの更新
- [ ] Breaking Changesの有無

## 関連ドキュメント

- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - デプロイ手順の詳細
- [CONTRIBUTING.md](../CONTRIBUTING.md) - コントリビューションガイド
- [.github/workflows/README.md](../../.github/workflows/README.md) - ワークフロー詳細
- [GROWTH_STRATEGY_ROADMAP.md](../GROWTH_STRATEGY_ROADMAP.md) - プロジェクト戦略

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025-11-14 | 1.0.0 | 初版作成 |
