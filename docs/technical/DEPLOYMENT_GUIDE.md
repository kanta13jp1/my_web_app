# Deployment Guide

> **⚠️ アーカイブ済 (2026-04-12 Windows版#56 確認)**: このドキュメントは 2025年11月時点のデプロイ手順書です。
> 現在は GitHub Actions `deploy-prod.yml` による自動デプロイが稼働中。最新手順は `docs/CICD_SETUP_GUIDE.md` を参照してください。

このドキュメントでは、各環境へのデプロイ手順、緊急時の手動デプロイ方法、ロールバック手順について説明します。

## 📋 目次

1. [環境概要](#環境概要)
2. [自動デプロイ](#自動デプロイ)
3. [手動デプロイ](#手動デプロイ)
4. [ロールバック手順](#ロールバック手順)
5. [環境変数の設定](#環境変数の設定)
6. [GitHub Secrets設定](#github-secrets設定)
7. [トラブルシューティング](#トラブルシューティング)

## 環境概要

### 環境一覧

| 環境 | ブランチ | URL | デプロイ方法 | 用途 |
|------|---------|-----|------------|------|
| **Development** | `develop` | https://dev.my-web-app-b67f4.web.app | 自動 | 開発中の機能テスト |
| **Staging** | `staging` | https://staging.my-web-app-b67f4.web.app | 自動 | 本番前の最終確認 |
| **Production** | `main` | my-web-app-b67f4.web.app | 自動 | 本番環境 |

### インフラ構成

各環境は以下のサービスで構成されています:

```
┌─────────────────────────────────────┐
│        Firebase Hosting             │  ← Flutter Web アプリ
├─────────────────────────────────────┤
│        Supabase                     │
│  ├─ Database (PostgreSQL)          │  ← データ保存
│  ├─ Authentication                 │  ← ユーザー認証
│  ├─ Storage                        │  ← ファイル保存
│  └─ Edge Functions                 │  ← サーバーレス関数
└─────────────────────────────────────┘
```

## 自動デプロイ

### Development環境への自動デプロイ

**トリガー**: `develop` ブランチへのpush

```bash
# feature ブランチをdevelopにマージ
git checkout develop
git pull origin develop
git merge feature/your-feature
git push origin develop
```

**実行される処理**:
1. CI チェック（Lint, Test, Build）
2. Supabase マイグレーション（開発DB）
3. Flutter Web ビルド（開発設定）
4. Firebase Hosting デプロイ（devチャネル）
5. Slack通知

**確認URL**: https://dev.my-web-app-b67f4.web.app

### Staging環境への自動デプロイ

**トリガー**: `staging` ブランチへのpush

```bash
# developをstagingにマージ
git checkout staging
git pull origin staging
git merge develop
git push origin staging
```

**実行される処理**:
1. CI チェック
2. Supabase マイグレーション（ステージングDB）
3. Flutter Web ビルド（ステージング設定）
4. Firebase Hosting デプロイ（stagingチャネル）
5. Slack通知

**確認URL**: https://staging.my-web-app-b67f4.web.app

### Production環境への自動デプロイ

**トリガー**: `main` ブランチへのpush

```bash
# stagingをmainにマージ
git checkout main
git pull origin main
git merge staging
git push origin main
```

**実行される処理**:
1. CI チェック
2. バージョン自動生成
3. Supabase マイグレーション（本番DB）
4. Flutter Web ビルド（本番設定、最適化）
5. Firebase Hosting デプロイ（liveチャネル）
6. Git リリースタグ作成
7. GitHub Release作成
8. Slack通知

**確認URL**: https://my-web-app-b67f4.web.app

## 手動デプロイ

緊急時やCI/CDパイプラインが利用できない場合の手動デプロイ手順です。

### 前提条件

以下のツールがインストールされている必要があります:

```bash
# Flutter SDK
flutter --version

# Firebase CLI
firebase --version

# Supabase CLI
supabase --version
```

### Development環境への手動デプロイ

#### 1. Supabaseマイグレーション

```bash
# Supabaseプロジェクトにリンク
supabase link --project-ref <SUPABASE_PROJECT_ID_DEV>

# マイグレーションを実行
supabase db push

# 確認
supabase db remote commit
```

#### 2. Flutter Webビルド

```bash
# 依存関係をインストール
flutter pub get

# ビルド
flutter build web --release --dart-define=ENVIRONMENT=development
```

#### 3. Firebaseデプロイ

```bash
# Firebaseにログイン
firebase login

# プロジェクトを選択
firebase use <FIREBASE_PROJECT_ID>

# devチャネルにデプロイ
firebase hosting:channel:deploy dev --expires 30d
```

### Staging環境への手動デプロイ

```bash
# Supabase
supabase link --project-ref <SUPABASE_PROJECT_ID_STAGING>
supabase db push

# Flutter Build
flutter build web --release --dart-define=ENVIRONMENT=staging

# Firebase
firebase hosting:channel:deploy staging --expires 30d
```

### Production環境への手動デプロイ

⚠️ **警告**: 本番環境への手動デプロイは慎重に行ってください。

```bash
# Supabase (本番DB)
supabase link --project-ref <SUPABASE_PROJECT_ID_PROD>

# マイグレーションのドライラン（必須）
supabase db push --dry-run

# 問題がなければ実行
supabase db push

# Flutter Build (最適化オプション付き)
flutter build web \
  --release \
  --web-renderer canvaskit \
  --dart-define=ENVIRONMENT=production \
  --tree-shake-icons

# Firebase (本番環境)
firebase deploy --only hosting

# リリースタグを作成
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## ロールバック手順

### 1. Firebase Hostingのロールバック

Firebase Hostingは以前のバージョンへのロールバックが可能です。

#### Firebase Consoleを使用する方法

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. プロジェクトを選択
3. `Hosting` → `リリース履歴` を開く
4. ロールバックしたいバージョンの「...」メニューから「ロールバック」を選択

#### CLIを使用する方法

```bash
# デプロイ履歴を確認
firebase hosting:clone <SITE_ID>:<PREVIOUS_VERSION_ID> <SITE_ID>:live

# 例
firebase hosting:clone my-app:a1b2c3d4 my-app:live
```

### 2. Supabaseマイグレーションのロールバック

Supabaseマイグレーションは慎重にロールバックする必要があります。

#### 方法1: マイグレーションファイルを元に戻す

```bash
# マイグレーションファイルの履歴を確認
ls -la supabase/migrations/

# 問題のあるマイグレーションファイルを特定
# 新しいマイグレーションで元に戻すSQLを作成
supabase migration new rollback_problematic_migration

# rollback用のSQLを記述
# 例: CREATE TABLEをDROP TABLEに変更など
```

#### 方法2: データベースバックアップから復元

```bash
# Supabaseダッシュボードからバックアップをダウンロード
# https://app.supabase.com/project/<PROJECT_ID>/settings/database

# ローカルで復元テスト
# 問題なければ本番DBに適用
```

### 3. コードのロールバック

```bash
# 問題のあるコミットを特定
git log --oneline

# 特定のコミットに戻す
git revert <COMMIT_HASH>

# または、強制的に戻す（注意！）
git reset --hard <COMMIT_HASH>
git push origin main --force

# 自動デプロイが走るのを待つ
```

### 緊急ロールバック手順（本番環境）

1. **即座にFirebase Hostingをロールバック**（上記手順）
2. **Slackで関係者に通知**
3. **Issueを作成して問題を追跡**
4. **原因調査と修正**
5. **修正後、通常のデプロイフローで再デプロイ**

## 環境変数の設定

### 環境変数ファイルの作成

各環境用の `.env` ファイルを作成します:

```bash
# 開発環境
cp .env.example .env.development

# ステージング環境
cp .env.example .env.staging

# 本番環境
cp .env.example .env.production
```

### 環境変数の編集

`.env.development` の例:

```bash
# Supabase Configuration
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_PROJECT_ID=xxxxx
SUPABASE_DB_PASSWORD=your_password

# Firebase Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_HOSTING_SITE=your-app

# Google AI Configuration
GOOGLE_AI_API_KEY=your_api_key

# Environment
ENVIRONMENT=development

# Feature Flags
ENABLE_AI_FEATURES=true
ENABLE_ANALYTICS=false
DEBUG_MODE=true
```

### Flutterコードでの環境変数の使用

```dart
// main.dart で環境変数を読み込む
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

await Supabase.initialize(
  url: supabaseUrl,
  anonKey: supabaseAnonKey,
);
```

### ビルド時の環境変数指定

```bash
flutter build web \
  --release \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=ENVIRONMENT=production
```

## GitHub Secrets設定

GitHub ActionsでCI/CDを実行するために、以下のSecretsを設定する必要があります。

### Secrets設定手順

1. GitHubリポジトリページにアクセス
2. `Settings` → `Secrets and variables` → `Actions` を開く
3. `New repository secret` をクリック
4. 必要なSecretsを追加

### 必要なSecrets一覧

#### Firebase関連

| Secret名 | 説明 | 取得方法 |
|---------|------|---------|
| `FIREBASE_PROJECT_ID` | FirebaseプロジェクトID | Firebase Console → プロジェクト設定 |
| `FIREBASE_SERVICE_ACCOUNT_DEV` | 開発環境用サービスアカウント | Firebase Console → サービスアカウント |
| `FIREBASE_SERVICE_ACCOUNT_STAGING` | ステージング環境用サービスアカウント | 同上 |
| `FIREBASE_SERVICE_ACCOUNT_PROD` | 本番環境用サービスアカウント | 同上 |

**Firebase Service Accountの取得方法**:

```bash
# Firebase CLIでログイン
firebase login

# サービスアカウントキーを生成
firebase service-account:create --json
```

#### Supabase関連

| Secret名 | 説明 | 取得方法 |
|---------|------|---------|
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI用アクセストークン | Supabase Dashboard → Settings → Access Tokens |
| `SUPABASE_PROJECT_ID_DEV` | 開発環境プロジェクトID | Supabase Dashboard → Settings → General |
| `SUPABASE_PROJECT_ID_STAGING` | ステージング環境プロジェクトID | 同上 |
| `SUPABASE_PROJECT_ID_PROD` | 本番環境プロジェクトID | 同上 |
| `SUPABASE_DB_PASSWORD_DEV` | 開発環境DB パスワード | プロジェクト作成時に設定 |
| `SUPABASE_DB_PASSWORD_STAGING` | ステージング環境DB パスワード | 同上 |
| `SUPABASE_DB_PASSWORD_PROD` | 本番環境DB パスワード | 同上 |
| `SUPABASE_URL_DEV` | 開発環境URL | Supabase Dashboard → Settings → API |
| `SUPABASE_URL_STAGING` | ステージング環境URL | 同上 |
| `SUPABASE_URL_PROD` | 本番環境URL | 同上 |
| `SUPABASE_ANON_KEY_DEV` | 開発環境 Anon Key | 同上 |
| `SUPABASE_ANON_KEY_STAGING` | ステージング環境 Anon Key | 同上 |
| `SUPABASE_ANON_KEY_PROD` | 本番環境 Anon Key | 同上 |

#### 通知関連

| Secret名 | 説明 | 取得方法 |
|---------|------|---------|
| `SLACK_WEBHOOK_URL` | Slack通知用WebhookURL | Slack → Apps → Incoming Webhooks |

**Slack Webhook URLの取得方法**:

1. Slackワークスペースにアクセス
2. [Incoming Webhooks](https://api.slack.com/messaging/webhooks) を設定
3. チャネルを選択してWebhook URLを生成

### Secretsの検証

Secretsが正しく設定されているか確認する方法:

```bash
# GitHub CLIを使用
gh secret list

# 特定のSecretを確認（値は表示されない）
gh secret get FIREBASE_PROJECT_ID
```

## トラブルシューティング

### デプロイが失敗する

#### 1. ビルドエラー

```bash
# ローカルでビルドをテスト
flutter clean
flutter pub get
flutter build web --release

# エラーメッセージを確認
```

#### 2. Supabaseマイグレーションエラー

```bash
# マイグレーションのドライランを実行
supabase db push --dry-run

# ログを確認
supabase functions logs
```

#### 3. Firebaseデプロイエラー

```bash
# デバッグモードでデプロイ
firebase deploy --only hosting --debug

# プロジェクト設定を確認
firebase projects:list
```

### パフォーマンス問題

#### ビルドサイズが大きい

```bash
# ビルドサイズを確認
du -sh build/web

# 最適化オプションを使用
flutter build web --release --tree-shake-icons --web-renderer canvaskit
```

#### ロード時間が遅い

1. Firebase Hosting CDNキャッシュを確認
2. 画像やアセットの最適化
3. Code Splittingの検討

### セキュリティ問題

#### シークレットが漏洩した場合

1. **即座にシークレットを無効化**
2. **新しいシークレットを生成**
3. **GitHub Secretsを更新**
4. **該当コミットを履歴から削除** (git-filter-repo使用)
5. **関係者に通知**

## ベストプラクティス

### デプロイ前のチェックリスト

- [ ] ローカルでCIチェックを実行済み
- [ ] 機能テストを完了
- [ ] データベースマイグレーションを確認
- [ ] 環境変数の設定を確認
- [ ] Breaking Changesがないか確認
- [ ] ロールバック計画を準備

### 本番デプロイ時の推奨手順

1. **ステージング環境で最終確認**
2. **関係者に事前通知**
3. **メンテナンス時間帯にデプロイ**（可能であれば）
4. **デプロイ後の動作確認**
5. **ログ監視**
6. **問題があれば即座にロールバック**

## 関連ドキュメント

- [CI_CD_GUIDE.md](./CI_CD_GUIDE.md) - CI/CDパイプライン概要
- [CONTRIBUTING.md](../CONTRIBUTING.md) - コントリビューションガイド
- [.github/workflows/README.md](../../.github/workflows/README.md) - ワークフロー詳細

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025-11-14 | 1.0.0 | 初版作成 |
