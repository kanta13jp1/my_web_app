# GitHub Actions Workflows

このディレクトリには、CI/CDパイプラインを構成するGitHub Actionsワークフローが含まれています。

## 📋 ワークフロー一覧

| ワークフロー | ファイル | トリガー | 用途 |
|------------|---------|---------|------|
| **CI** | `ci.yml` | すべてのPR | コード品質チェック |
| **Deploy to Development** | `deploy-dev.yml` | `develop` へのpush | 開発環境デプロイ |
| **Deploy to Staging** | `deploy-staging.yml` | `staging` へのpush | ステージング環境デプロイ |
| **Deploy to Production** | `deploy-prod.yml` | `main` へのpush | 本番環境デプロイ |

## ワークフロー詳細

### 1. CI (`ci.yml`)

継続的インテグレーション（CI）ワークフロー。すべてのPRに対して自動実行されます。

#### トリガー条件

```yaml
on:
  pull_request:
    branches:
      - main
      - staging
      - develop
  push:
    branches:
      - main
      - staging
      - develop
```

#### 実行ジョブ

##### `lint-and-test`

1. **Checkout code**: リポジトリをチェックアウト
2. **Setup Flutter**: Flutter環境をセットアップ (v3.24.x)
3. **Get Flutter version**: Flutterバージョンを確認
4. **Install dependencies**: `flutter pub get`
5. **Verify dependencies**: 依存関係の検証
6. **Analyze code**: `flutter analyze`
7. **Check formatting**: `dart format --set-exit-if-changed .`
8. **Run tests**: `flutter test --coverage`
9. **Upload coverage**: Codecovへカバレッジをアップロード
10. **Build web**: `flutter build web --release`
11. **Check build output**: ビルド出力の検証

##### `security-check`

1. **Checkout code**: リポジトリをチェックアウト
2. **Run security audit**: 機密ファイルのチェック
3. **Check for hardcoded secrets**: ハードコードされたシークレットのチェック

##### `build-matrix`

複数のFlutterバージョンでビルドをテスト

##### `pr-comment`

CIが成功した場合、PRにコメントを追加

#### 失敗時の対処法

**Lintエラーが発生した場合**:

```bash
# ローカルで確認
flutter analyze

# 自動修正可能な問題を修正
dart fix --apply
```

**フォーマットエラーが発生した場合**:

```bash
# フォーマットを適用
dart format .
```

**テストが失敗した場合**:

```bash
# ローカルでテスト実行
flutter test

# 特定のテストのみ実行
flutter test test/services/user_service_test.dart
```

---

### 2. Deploy to Development (`deploy-dev.yml`)

開発環境への自動デプロイワークフロー。

#### トリガー条件

```yaml
on:
  push:
    branches:
      - develop
  workflow_dispatch:  # 手動実行も可能
```

#### 実行ジョブ

##### `ci`

CI ワークフローを再利用して実行

##### `deploy`

1. **Checkout code**: リポジトリをチェックアウト
2. **Setup Flutter**: Flutter環境をセットアップ
3. **Install dependencies**: `flutter pub get`
4. **Setup Supabase CLI**: Supabase CLIをセットアップ
5. **Run Supabase migrations**: 開発環境DBへマイグレーション実行
6. **Build Flutter Web**: 開発設定でビルド
7. **Verify build output**: ビルド出力の検証
8. **Deploy to Firebase Hosting**: Firebaseへデプロイ (devチャネル)

##### `notify`

Slackへデプロイ結果を通知

#### 必要なSecrets

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_ID_DEV`
- `SUPABASE_DB_PASSWORD_DEV`
- `SUPABASE_URL_DEV`
- `SUPABASE_ANON_KEY_DEV`
- `FIREBASE_SERVICE_ACCOUNT_DEV`
- `FIREBASE_PROJECT_ID`
- `SLACK_WEBHOOK_URL` (オプション)

#### 失敗時の対処法

**Supabaseマイグレーションが失敗した場合**:

```bash
# ローカルでマイグレーションをテスト
supabase link --project-ref <SUPABASE_PROJECT_ID_DEV>
supabase db push --dry-run

# エラーを確認して修正
```

**Firebaseデプロイが失敗した場合**:

```bash
# ローカルでデプロイをテスト
firebase deploy --only hosting --debug

# サービスアカウントの権限を確認
```

---

### 3. Deploy to Staging (`deploy-staging.yml`)

ステージング環境への自動デプロイワークフロー。

#### トリガー条件

```yaml
on:
  push:
    branches:
      - staging
  workflow_dispatch:
```

#### 実行内容

Development環境デプロイと同様ですが、ステージング環境向けの設定を使用します。

#### 必要なSecrets

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_ID_STAGING`
- `SUPABASE_DB_PASSWORD_STAGING`
- `SUPABASE_URL_STAGING`
- `SUPABASE_ANON_KEY_STAGING`
- `FIREBASE_SERVICE_ACCOUNT_STAGING`
- `FIREBASE_PROJECT_ID`
- `SLACK_WEBHOOK_URL` (オプション)

---

### 4. Deploy to Production (`deploy-prod.yml`)

本番環境への自動デプロイワークフロー。バージョニングとリリース作成が含まれます。

#### トリガー条件

```yaml
on:
  push:
    branches:
      - main
  workflow_dispatch:
```

#### 実行ジョブ

##### `ci`

CI ワークフローを再利用して実行

##### `deploy`

1. **Checkout code**: リポジトリをチェックアウト (全履歴取得)
2. **Setup Flutter**: Flutter環境をセットアップ
3. **Install dependencies**: `flutter pub get`
4. **Generate version**: Gitタグから自動でバージョン生成
5. **Setup Supabase CLI**: Supabase CLIをセットアップ
6. **Run Supabase migrations**: 本番環境DBへマイグレーション実行
7. **Build Flutter Web**: 本番設定でビルド（最適化オプション付き）
8. **Verify build output**: ビルド出力とサイズの確認
9. **Deploy to Firebase Hosting**: Firebaseへデプロイ (liveチャネル)
10. **Create Release Tag**: Gitリリースタグを作成
11. **Create GitHub Release**: GitHub Releaseを作成

##### `notify`

Slackへデプロイ結果を通知（本番用の詳細な通知）

#### バージョニングロジック

```bash
# 最新タグを取得 (例: v1.2.3)
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")

# パッチバージョンをインクリメント
# v1.2.3 → v1.2.4
```

#### 必要なSecrets

- `SUPABASE_ACCESS_TOKEN`
- `SUPABASE_PROJECT_ID_PROD`
- `SUPABASE_DB_PASSWORD_PROD`
- `SUPABASE_URL_PROD`
- `SUPABASE_ANON_KEY_PROD`
- `FIREBASE_SERVICE_ACCOUNT_PROD`
- `FIREBASE_PROJECT_ID`
- `SLACK_WEBHOOK_URL` (オプション)

#### 失敗時の対処法

**バージョン生成が失敗した場合**:

```bash
# 手動でタグを作成
git tag v1.0.0
git push origin v1.0.0
```

**本番デプロイが失敗した場合**:

1. **即座にロールバック**: [DEPLOYMENT_GUIDE.md](../../docs/technical/DEPLOYMENT_GUIDE.md#ロールバック手順) を参照
2. **Slackで関係者に通知**
3. **Issueを作成して問題を追跡**

---

## ワークフローの手動実行

すべてのデプロイワークフローは手動実行 (`workflow_dispatch`) をサポートしています。

### 手動実行方法

1. GitHubリポジトリページにアクセス
2. `Actions` タブを開く
3. 実行したいワークフローを選択
4. `Run workflow` ボタンをクリック
5. ブランチを選択して `Run workflow` を実行

### 使用例

- **緊急デプロイ**: PRマージを待たずにデプロイ
- **再デプロイ**: 失敗したデプロイを再実行
- **テスト**: ワークフローのテスト

---

## ワークフローの監視

### GitHub Actions UI

1. リポジトリページの `Actions` タブを開く
2. ワークフローの実行履歴を確認
3. 失敗したワークフローのログを確認

### ステータスバッジ

README.mdにステータスバッジを追加して、ワークフローの状態を表示できます:

```markdown
[![CI](https://github.com/kanta13jp1/my_web_app/actions/workflows/ci.yml/badge.svg)](https://github.com/kanta13jp1/my_web_app/actions/workflows/ci.yml)
```

---

## トラブルシューティング

### よくある問題

#### 1. Secretsが設定されていない

**症状**: デプロイが失敗し、"Secret not found" エラーが表示される

**解決方法**:
1. リポジトリの `Settings` → `Secrets and variables` → `Actions` を開く
2. 必要なSecretsを追加
3. [DEPLOYMENT_GUIDE.md](../../docs/technical/DEPLOYMENT_GUIDE.md#github-secrets設定) を参照

#### 2. ワークフローがトリガーされない

**症状**: ブランチにpushしてもワークフローが実行されない

**解決方法**:
1. ワークフローファイルの `on` セクションを確認
2. ブランチ名が正しいか確認
3. `.github/workflows/` ディレクトリに正しく配置されているか確認

#### 3. CIチェックが常に失敗する

**症状**: PRを作成するたびにCIが失敗する

**解決方法**:
1. ローカルで同じチェックを実行
   ```bash
   flutter analyze
   dart format --set-exit-if-changed .
   flutter test
   flutter build web --release
   ```
2. エラーメッセージを確認して修正
3. `.github/workflows/ci.yml` の設定を確認

#### 4. デプロイは成功するが動作しない

**症状**: デプロイは成功するが、アプリが正しく動作しない

**解決方法**:
1. ブラウザのコンソールでエラーを確認
2. 環境変数が正しく設定されているか確認
3. Firebase Hosting の設定を確認
4. Supabase の接続を確認

---

## ベストプラクティス

### 1. ワークフローの変更

ワークフローファイルを変更する際は:

- **テストブランチで検証**: 本番に影響を与えないブランチでテスト
- **段階的にロールアウト**: まずdevelopment環境で試す
- **ドキュメントを更新**: このREADMEを更新

### 2. Secretsの管理

- **定期的にローテーション**: セキュリティのため定期的に更新
- **最小権限の原則**: 必要最小限の権限のみ付与
- **環境ごとに分離**: development/staging/production で別々のSecretsを使用

### 3. モニタリング

- **Slackアラート**: 失敗時の通知を設定
- **定期的なレビュー**: ワークフローログを定期的に確認
- **メトリクスの追跡**: デプロイ頻度や成功率を追跡

---

## 関連ドキュメント

- [CI_CD_GUIDE.md](../../docs/technical/CI_CD_GUIDE.md) - CI/CDパイプライン全体の概要
- [DEPLOYMENT_GUIDE.md](../../docs/technical/DEPLOYMENT_GUIDE.md) - デプロイ手順詳細
- [CONTRIBUTING.md](../../docs/CONTRIBUTING.md) - コントリビューションガイド

---

## 更新履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2025-11-14 | 1.0.0 | 初版作成 |
