# CI/CD環境セットアップガイド 🚀

**作成日**: 2025年11月14日
**目的**: CI/CDパイプラインを有効化するための環境セットアップ手順

---

## 📋 概要

このドキュメントでは、既に構築されたCI/CDパイプラインを有効化するために必要な手動セットアップ手順を説明します。

### 完了済み ✅
- ✅ GitHub Actionsワークフローファイル作成（4ファイル）
- ✅ CI/CDガイドドキュメント作成
- ✅ デプロイメントガイド作成
- ✅ ブランチ保護設定ガイド作成
- ✅ develop/stagingブランチ作成（ローカル）

### 必須作業 🔒
1. **GitHub Secretsの設定** ⚠️ 最優先
2. **ブランチをリモートにプッシュ**
3. **ブランチ保護ルールの設定**

---

## 🔐 手順1: GitHub Secretsの設定

GitHub ActionsでCI/CDを実行するために、以下のSecretsを設定する必要があります。

### Secrets設定場所

1. GitHubリポジトリページにアクセス: https://github.com/kanta13jp1/my_web_app
2. `Settings` → `Secrets and variables` → `Actions` を開く
3. `New repository secret` をクリック
4. 以下のSecretsを追加

### 必須Secrets一覧

#### 🔥 Firebase関連（4個）

| Secret名 | 説明 | 取得方法 |
|---------|------|---------|
| `FIREBASE_PROJECT_ID` | FirebaseプロジェクトID | Firebase Console → プロジェクト設定 → プロジェクトID |
| `FIREBASE_SERVICE_ACCOUNT_DEV` | 開発環境用サービスアカウント（JSON） | 下記「Firebase Service Account取得方法」参照 |
| `FIREBASE_SERVICE_ACCOUNT_STAGING` | ステージング環境用サービスアカウント（JSON） | 同上 |
| `FIREBASE_SERVICE_ACCOUNT_PROD` | 本番環境用サービスアカウント（JSON） | 同上 |

**Firebase Service Accountの取得方法**:

```bash
# 1. Firebase CLIでログイン
firebase login

# 2. プロジェクトを選択
firebase projects:list

# 3. サービスアカウントキーを生成
firebase service-account:create --json

# 4. 出力されたJSONをそのままGitHub Secretに貼り付け
```

または、Firebase Consoleから取得:
1. Firebase Console → プロジェクト設定 → サービスアカウント
2. 「新しい秘密鍵の生成」をクリック
3. ダウンロードしたJSONファイルの内容をコピー
4. GitHub Secretに貼り付け

#### 🗄️ Supabase関連（12個）

| Secret名 | 説明 | 取得方法 |
|---------|------|---------|
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI用アクセストークン | Supabase Dashboard → Account → Access Tokens → Generate new token |
| `SUPABASE_PROJECT_ID_DEV` | 開発環境プロジェクトID | Supabase Dashboard → Settings → General → Reference ID |
| `SUPABASE_PROJECT_ID_STAGING` | ステージング環境プロジェクトID | 同上（別プロジェクト） |
| `SUPABASE_PROJECT_ID_PROD` | 本番環境プロジェクトID | 同上（別プロジェクト） |
| `SUPABASE_DB_PASSWORD_DEV` | 開発環境DB パスワード | プロジェクト作成時に設定したパスワード |
| `SUPABASE_DB_PASSWORD_STAGING` | ステージング環境DB パスワード | 同上 |
| `SUPABASE_DB_PASSWORD_PROD` | 本番環境DB パスワード | 同上 |
| `SUPABASE_URL_DEV` | 開発環境URL | Supabase Dashboard → Settings → API → Project URL |
| `SUPABASE_URL_STAGING` | ステージング環境URL | 同上（別プロジェクト） |
| `SUPABASE_URL_PROD` | 本番環境URL | 同上（別プロジェクト） |
| `SUPABASE_ANON_KEY_DEV` | 開発環境 Anon Key | Supabase Dashboard → Settings → API → anon/public key |
| `SUPABASE_ANON_KEY_STAGING` | ステージング環境 Anon Key | 同上（別プロジェクト） |
| `SUPABASE_ANON_KEY_PROD` | 本番環境 Anon Key | 同上（別プロジェクト） |

#### 📢 通知関連（1個、オプション）

| Secret名 | 説明 | 取得方法 |
|---------|------|---------|
| `SLACK_WEBHOOK_URL` | Slack通知用WebhookURL | Slack → Apps → Incoming Webhooks → Add to Slack |

**Slack Webhook URLの取得方法**:
1. Slackワークスペースにアクセス
2. https://api.slack.com/messaging/webhooks にアクセス
3. 「Create New App」→ 「From scratch」
4. App名とワークスペースを選択
5. 「Incoming Webhooks」を有効化
6. 「Add New Webhook to Workspace」をクリック
7. 通知先チャネルを選択
8. 生成されたWebhook URLをコピーしてGitHub Secretに追加

### 環境が1つの場合の設定

現在、開発・ステージング・本番で**同じSupabaseプロジェクト**を使用している場合:

```
SUPABASE_PROJECT_ID_DEV = SUPABASE_PROJECT_ID_STAGING = SUPABASE_PROJECT_ID_PROD
SUPABASE_DB_PASSWORD_DEV = SUPABASE_DB_PASSWORD_STAGING = SUPABASE_DB_PASSWORD_PROD
SUPABASE_URL_DEV = SUPABASE_URL_STAGING = SUPABASE_URL_PROD
SUPABASE_ANON_KEY_DEV = SUPABASE_ANON_KEY_STAGING = SUPABASE_ANON_KEY_PROD
```

**推奨**: 将来的には環境ごとにSupabaseプロジェクトを分けることを推奨します。

### Secretsの検証

設定が完了したら、以下のコマンドで確認（値は表示されません）:

```bash
# GitHub CLIを使用
gh secret list

# 出力例:
# FIREBASE_PROJECT_ID
# FIREBASE_SERVICE_ACCOUNT_DEV
# SUPABASE_ACCESS_TOKEN
# ...
```

---

## 🌿 手順2: ブランチをリモートにプッシュ

ローカルで作成した `develop` と `staging` ブランチをリモートにプッシュします。

### コマンド

```bash
# 1. developブランチをプッシュ
git checkout develop
git push -u origin develop

# 2. stagingブランチをプッシュ
git checkout staging
git push -u origin staging

# 3. 確認
git branch -a
# develop
# staging
# * main
# remotes/origin/develop
# remotes/origin/staging
# remotes/origin/main
```

---

## 🛡️ 手順3: ブランチ保護ルールの設定

リモートにブランチをプッシュした後、ブランチ保護ルールを設定します。

### 設定場所

1. GitHubリポジトリページ: https://github.com/kanta13jp1/my_web_app
2. `Settings` → `Branches`
3. `Branch protection rules` → `Add rule`

### main ブランチの保護設定 🔒

**Branch name pattern**: `main`

**有効にする設定**:
- ✅ Require a pull request before merging
  - Require approvals: `1`
  - Dismiss stale pull request approvals when new commits are pushed
- ✅ Require status checks to pass before merging
  - Require branches to be up to date before merging
  - Status checks: `lint-and-test`, `security-check`, `build-matrix`
- ✅ Require conversation resolution before merging
- ✅ Include administrators

### staging ブランチの保護設定 🔒

**Branch name pattern**: `staging`

**有効にする設定**:
- ✅ Require a pull request before merging
  - Require approvals: `1`（オプション）
- ✅ Require status checks to pass before merging
  - Status checks: `lint-and-test`, `security-check`, `build-matrix`
- ✅ Include administrators

### develop ブランチの保護設定 🔒

**Branch name pattern**: `develop`

**有効にする設定**:
- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
  - Status checks: `lint-and-test`, `security-check`, `build-matrix`

**詳細な設定手順**: `docs/technical/BRANCH_PROTECTION_SETUP.md` を参照

---

## ✅ 手順4: 動作確認

すべての設定が完了したら、以下の手順で動作確認を行います。

### 1. CI動作確認

```bash
# 1. テストブランチを作成
git checkout develop
git checkout -b feature/test-ci

# 2. 適当な変更を加える
echo "# CI Test" >> test.md

# 3. コミット＆プッシュ
git add test.md
git commit -m "test: CI動作確認"
git push -u origin feature/test-ci

# 4. GitHub上でPRを作成
# https://github.com/kanta13jp1/my_web_app/compare/develop...feature/test-ci

# 5. CIが自動実行されることを確認
# - lint-and-test ✅
# - security-check ✅
# - build-matrix ✅
```

### 2. デプロイ動作確認

```bash
# 1. テストブランチをdevelopにマージ
# GitHub上でPRをマージ

# 2. GitHub Actionsを確認
# https://github.com/kanta13jp1/my_web_app/actions

# 3. デプロイが自動実行されることを確認
# - Deploy to Development ワークフローが実行される
# - 完了後、コミットにコメントが追加される

# 4. デプロイされたアプリを確認
# https://dev.your-app.web.app
```

---

## 🎯 次のステップ

CI/CD環境のセットアップが完了したら、以下のタスクに進みます:

### 最優先タスク（今週中）

1. **緊急バグ修正** 🐛
   - ドキュメント表示修正（アセット読み込みエラー）
   - AI機能の動作確認とテスト
   - 参照: `docs/COMPREHENSIVE_BUG_ANALYSIS.md`

2. **Product Hunt準備開始** 📢
   - デモ動画作成
   - スクリーンショット準備
   - 製品説明文作成
   - 予想効果: 500-2,000ユーザー獲得

### 高優先度タスク（2週間以内）

1. **OGP画像自動生成機能** 🎨
   - Twitterシェア時の画像生成
   - 性格診断結果の美しい画像化
   - 予想効果: シェア率30% → 50%

2. **シェアインセンティブ実装** 🎁
   - シェアで1,000ポイント獲得
   - 友達招待機能
   - 予想効果: バイラル係数+0.5

3. **新機能実装**
   - 画面遷移しない保存ボタン（Notionライク）
   - 自動保存機能（デバウンス付き）
   - UNDO/REDO機能

**詳細な計画**: `docs/GROWTH_STRATEGY_ROADMAP.md` を参照

---

## 📚 関連ドキュメント

- **[CI/CD Pipeline Guide](./technical/CI_CD_GUIDE.md)** - CI/CDパイプラインの詳細
- **[Deployment Guide](./technical/DEPLOYMENT_GUIDE.md)** - デプロイ・ロールバック手順
- **[Branch Protection Setup](./technical/BRANCH_PROTECTION_SETUP.md)** - ブランチ保護設定
- **[Growth Strategy Roadmap](./GROWTH_STRATEGY_ROADMAP.md)** - 開発ロードマップ

---

## ❓ トラブルシューティング

### GitHub Secretsが見つからない

**問題**: ワークフローで「Secret not found」エラー

**解決策**:
1. Secret名のスペルミスを確認
2. リポジトリの Settings → Secrets and variables → Actions で設定されているか確認
3. 環境別Secretsの場合、環境が作成されているか確認

### CI/CDが実行されない

**問題**: PRを作成してもCIが実行されない

**解決策**:
1. `.github/workflows/` にワークフローファイルが存在するか確認
2. ワークフローファイルのYAML構文エラーを確認
3. GitHub Actions タブでエラーを確認

### デプロイが失敗する

**問題**: デプロイワークフローがエラーで終了

**解決策**:
1. GitHub Secretsが正しく設定されているか確認
2. Firebase/Supabaseの認証情報が有効か確認
3. ワークフローログで詳細なエラーメッセージを確認
4. `docs/technical/DEPLOYMENT_GUIDE.md` のトラブルシューティングを参照

---

## 📞 サポート

セットアップで問題が発生した場合:

1. このドキュメントのトラブルシューティングセクションを確認
2. 関連ドキュメントを参照
3. GitHub Actionsのワークフローログを確認
4. GitHubのIssueを作成

---

**セットアップが完了したら、このドキュメントの冒頭に完了日時を記録してください。**

✅ **セットアップ完了日**: ________________ （記入してください）
