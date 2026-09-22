# GitHub Actions Workflows

このディレクトリには、CI/CDパイプラインを構成するGitHub Actionsワークフローが含まれています。

- **Infrastructure Documentation** (`infrastructure-docs.yml`): main の関連変更から Supabase / GitHub Actions 構成図を生成し、Actions artifact と `generated/infrastructure-docs` ブランチへ公開します。

2026-05-07 #1706: AI-tool workflow changes must cite official sources, stay in the Claude Code #1 + Codex #1 two-instance flow, and avoid starting persistent local dev server / node / dart processes.

2026-05-17 #2535: Guarded child subagents are allowed under Claude Code #1 or
Codex #1 for bounded research, critique, memory review, large-output
inspection, or disjoint implementation. They must not become new workflow/WBS
owners or leave persistent local processes behind.

## Paid Claude/Codex billing suspension (2026-08-30)

Owner decision: paid Claude and Codex automation remains disabled until the
repository reaches **zero open GitHub Issues**. The repository variable
`PAID_AI_CLAUDE_CODEX_ENABLED` is `false`, and affected workflows remain
manually disabled while the policy change is reviewed.

Every credential-bearing workflow also uses
`.github/actions/paid-ai-policy`. Even if a workflow is re-enabled by mistake,
it receives no Anthropic credential or OpenAI WIF configuration unless both
conditions are proven:

1. the owner manually sets `PAID_AI_CLAUDE_CODEX_ENABLED=true`; and
2. the live GitHub search reports `is:issue is:open` count `0`.

An Issue-count lookup failure is fail-closed. Reactivation is never automatic.
`quota-monitor.yml` remains active because it reads administrative cost data
and does not submit model inference requests.

## 📋 ワークフロー一覧

| ワークフロー | ファイル | トリガー | 用途 |
| --- | --- | --- | --- |
| **CI** | `ci.yml` | PR + push (main/staging/develop) | flutter analyze **0エラー強制** + deno lint **0エラー強制** + ビルド検証 + Job Summary |
| **Deploy to Development** | `deploy-dev.yml` | `develop` へのpush | 開発環境デプロイ (concurrency制御・timeout付き) |
| **Deploy to Staging** | `deploy-staging.yml` | `staging` へのpush | ステージング環境デプロイ (concurrency制御・timeout付き) |
| **Deploy to Production** | `deploy-prod.yml` | `main` へのpush | 本番環境デプロイ + バージョニング (concurrency制御・timeout付き) |
| **Release Readiness Gate** | `release-readiness.yml` | deploy-prod success / daily 06:40 JST / manual | #1556 alpha gate: migration + EF import + Deno lint + readiness hub Deno check + Flutter build + production route + tools-hub/schedule-hub + Notion + Slack + WBS update |
| **Blog News Production Smoke** | `blog-news-prod-smoke.yml` | deploy-prod success / manual | #1950 blog/news E2E guard: `/blog`, `/blog/compose`, `/news-rss`, optional `/blog/post?id=<postId>`, RSS Edge Function, and read-only `blog_posts` queue state |
| **Mobile Distribution Readiness** | `mobile-distribution-readiness.yml` | mobile release PR / mobile-release-build success / manual | #1495 iOS/Android distribution gate: metadata, signing placeholders, docs, workflow wiring, and boolean-only signing/store secret presence report |
| **Video Pipeline Secret Readiness** | `video-pipeline-secret-readiness.yml` | video pipeline PR / manual | #1724 NotebookLM video-pipeline gate: boolean-only presence report for `GITHUB_PAT`, `NOTEBOOKLM_STORAGE_STATE_JSON`, `ELEVENLABS_API_KEY`, `YOUTUBE_CLIENT_SECRET_JSON`, and `YOUTUBE_TOKEN_JSON` |
| **Daily Report** | `daily-report.yml` | 毎日 07:30 JST / 手動 | 日次レポート生成 + X投稿 + 競合モニタリング + schedule_task_runs記録 + Job Summary |
| **CS Check** | `cs-check.yml` | 毎時 07分 / 手動 | CS自動対応 + PR自動レビュー + schedule_task_runs記録 + Job Summary |
| **Edge Function Audit** | `edge-function-audit.yml` | 毎時 47分 / 手動 | EF UI導線カバレッジチェック + schedule_task_runs記録 + Job Summary |
| **Health Monitor (統合)** | `health-monitor.yml` | 2時間毎 00分 / 手動 | サポートチケット + Firebase + 重要EF 6件監視 (旧 infra-health-check.yml を 2026-07-17 統合) + health-status.json/infra-status.json 更新 + schedule_task_runs記録 + Job Summary |
| **tools-hub MCP Smoke** | `tools-hub-mcp-smoke.yml` | 6時間毎 / 手動 | tools-hub MCP facade の metadata / tools/list / auth gate / optional AuthKit token smoke + schedule_task_runs記録 |
| **NotebookLM Intake Gate** | `notebooklm-intake-gate.yml` | Daily 06:45 JST / manual | Normalize `notebooklm list --json`, deduplicate against Issues/docs, and update `docs/notebooklm-intake` for #1606 |
| **Dependency Audit** | `dependency-audit.yml` | 毎週月曜 08:00 JST / 手動 | Flutter pub outdated + Deno import バージョン監査 + schedule_task_runs記録 + Job Summary |
| **Claude Agent PR Review** | `claude-agent-review.yml` | 手動停止中 | **課金停止中** — Issues=0 + owner opt-in後のみClaude認証情報を利用 |
| **User Feedback Resolved** | `feedback-issue-resolved.yml` | issues: [closed] | `user-feedback` ラベルIssueクローズ → `notify-feature-request` EF でリリース通知メール |
| **Workflow Failure Handler** | `workflow-failure-handler.yml` | workflow_run: [completed] | workflow-failure Issue clustering by root-cause key, duplicate comments, and recovery auto-close |
| **YouTube Analysis** | `youtube-analysis.yml` | 毎日 11:00 JST / 手動 | YouTube競合分析スナップショット (`fetch_yt.py` + `update_tsv.py`) → `updated_table.tsv` PR自動マージ |
| **CI Auto-Fix** | `ci-auto-fix.yml` | workflow_run: CI失敗時 | PR の `dart fix --apply` + `deno fmt` 自動修復コミット → 結果をPRにコメント |
| **Blog Publish** | `blog-publish.yml` | workflow_dispatch | 技術記事手動投稿 (Qiita/dev.to) — `draft_path` / `platforms` / `dry_run` 入力。投稿後 frontmatter `published:true` 更新 |
| **AI大学コンテンツ更新** | `ai-university-update.yml` | 毎週月曜 11:00 JST / 手動 | 6+プロバイダー (Google/OpenAI/Anthropic/Microsoft/Meta/X/DeepSeek) の最新ニュースを RSS 取得 → `ai_university_content` テーブル UPSERT |

## 品質保証指標 (全17ワークフロー)

| 指標 | 状態 |
| --- | --- |
| `flutter analyze` 0エラー強制ゲート | ✅ ci.yml |
| `deno lint` 0エラー強制ゲート | ✅ ci.yml |
| EF未分類チェック (Tier1/2カバレッジ) | ✅ ci.yml (未分類0本達成) |
| `concurrency` 制御 (並列実行防止) | ✅ 全17本 |
| `timeout-minutes` (ハング防止) | ✅ 全17本 |
| `permissions` 最小権限原則 | ✅ 全17本 (全ジョブ) |
| `persist-credentials: false` (読み取り専用ワークフロー) | ✅ 4本 (edge-function-audit / dependency-audit / cron-batch / claude-agent-review) |
| Slack webhook `--max-time 10 \|\| true` (障害耐性) | ✅ deploy-prod / cron-batch |
| アクションバージョン固定 (floating tag なし) | ✅ 全17本 |
| `schedule_task_runs` DB記録 | ✅ スケジュール9本 (daily-report/cs-check/ef-audit/infra-health/cron-batch/dep-audit/youtube-analysis/ci-auto-fix/ai-university-update) |
| `$GITHUB_STEP_SUMMARY` | ✅ 全17本 |
| `dependabot` 自動更新 | ✅ Actions + pub + pip (毎週月曜) |
| **Claude Managed Agents 統合** | ⏸ 課金停止中 (`PAID_AI_CLAUDE_CODEX_ENABLED=false`) |
| **ユーザーフィードバックパイプライン** | ✅ feedback-issue-resolved.yml (`SUPABASE_SERVICE_ROLE_KEY` 使用) |
| **CI失敗自動修復** | ✅ ci-auto-fix.yml (`dart fix --apply` + `dart format` + `deno fmt` → PR自動コミット) |
| **YouTube競合分析自動化** | ✅ youtube-analysis.yml (`yt-dlp` 毎日スナップショット → TSV更新) |
| **技術記事手動投稿** | ✅ blog-publish.yml (Qiita/dev.to `workflow_dispatch` + dry_run対応) |
| **AI大学コンテンツ週次自動更新** | ✅ ai-university-update.yml (毎週月曜 11:00 JST RSS取得・UPSERT) |

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
2. **Setup Flutter**: Flutter環境をセットアップ (v3.38.x)
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
- `SUPABASE_PUBLISHABLE_KEY_DEV`（`SUPABASE_ANON_KEY_DEV` は移行期間のfallbackのみ）
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
- `SUPABASE_PUBLISHABLE_KEY_STAGING`（`SUPABASE_ANON_KEY_STAGING` は移行期間のfallbackのみ）
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
- `SUPABASE_PUBLISHABLE_KEY_PROD`（`SUPABASE_ANON_KEY_PROD` は移行期間のfallbackのみ）
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
| --- | --- | --- |
| 2025-11-14 | 1.0.0 | 初版作成 |
| 2026-04-10 | 1.1.0 | Flutter v3.38.x / dependabot pip追加 / schedule_task_runs記録6本に修正 / PS#28-34品質改善反映 |
| 2026-04-10 | 1.2.0 | Claude Managed Agents 統合: `claude-agent-review.yml` 新設 (11本体制) / EF総数238→240反映 |
| 2026-04-10 | 1.3.0 | ユーザーフィードバックパイプライン: `feedback-issue-resolved.yml` 新設 (12本体制) |
| 2026-04-10 | 1.4.0 | ワークフロー失敗Issue自動生成: `workflow-failure-handler.yml` 新設 (13本体制) |
| 2026-04-11 | 1.5.0 | YouTube競合分析自動化: `youtube-analysis.yml` 新設 + `requirements.txt` yt-dlp追加 (14本体制) |
| 2026-04-11 | 1.6.0 | CI失敗自動修復: `ci-auto-fix.yml` 新設 — dart fix + deno fmt → PR自動コミット (15本体制) |
| 2026-04-11 | 1.7.0 | 技術記事投稿ワークフロー: `blog-publish.yml` 新設 — Qiita/dev.to 手動投稿 + dry_run対応 (16本体制) |
