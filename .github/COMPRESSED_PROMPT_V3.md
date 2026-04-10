# 自分株式会社 統合プロンプト（圧縮版 v3）

## 🎯 ミッション

Flutter Web + Supabase で **21競合を統合するAIライフマネジメントアプリ** を構築。
本番: <https://my-web-app-b67f4.web.app/> / 実ユーザー: **4人** / **完成と言えるまで自己レビューを繰り返すこと**。

---

## 🔀 4インスタンス並行開発スコープ

| インスタンス | 担当範囲 | 変更禁止 |
| --- | --- | --- |
| **VSCode版** | `lib/` (Flutter UI・193ページ・ウィジェット) | 他3範囲 |
| **Web版** | `supabase/functions/` (Edge Functions 241本) | 他3範囲 |
| **Windows版** | `docs/` + `supabase/migrations/` + seed SQL | 他3範囲 |
| **PowerShell版** | `.github/workflows/` + CI/CD (13本完備済み) | 他3範囲 |

**競合回避パターン（必須）**: `git stash → git pull --rebase origin main → git push origin main → git stash pop`
衝突時: `git checkout --theirs <file>` → `git add` → `git rebase --continue`

---

## 🏆 競合21社（全機能を統合して超える）

notion, evernote, moneyforward, x, animaworks, claude-code, codex, netkeiba, openclaw, claude-cowork, chatwork, slack, jobcan, amazon, google, microsoft, discord, line, facebook, liven, github

---

## 📊 必須実装（ホーム画面21本の進捗バー）

各競合1本ずつ **短期/中期/長期目標** + 現在達成率を表示。`get-growth-roadmap-progress` EF がデータ源。

---

## 🧩 コア機能リスト（実装済み含む）

| # | 機能 | 状態 | 主要EF / 担当 |
| --- | --- | --- | --- |
| 1 | **競合機能比較ページ** (21社×機能マトリクス) | ✅ | `get-competitor-features` |
| 2 | **EF UI導線カバレッジ** (未接続→GitHub Issue自動生成) | ✅ | `edge-function-coverage` |
| 3 | **開発実績タイムライン** | ✅ | `development-achievements` |
| 4 | **ブログ自動投稿** (Zenn/Qiita/note/dev.to等, `blog_posts`テーブル管理) | ✅ | `blog-post-manager`, `blog-auto-publisher` |
| 5 | **モバイルギターレコーディングスタジオ** (H.264録画 + X自動シェア + AI演奏評価) | ✅ | `guitar-recording-studio` |
| 6 | **AI仮想秘書** (日次判定・タスク提案・スケジュール管理) | ✅ | `daily-judgment`, `ai-assistant` |
| 7 | **地方選挙インテリジェンス** (47都道府県×1年先×週末X投稿) | ✅ | `local-election-intelligence`, `gemini-election-analysis` |
| 8 | **バイラル動画パイプライン** (自動生成→投稿→効果測定) | 実装中 | `viral-video-generator`, `viral-growth-pipeline` |
| 9 | **Real Value YouTube競合分析** | 実装中 | Python: `fetch_yt.py` |
| 10 | **メモ画像貼り付け** (Note/Notion風ドラッグ&ドロップ + クリップボードペースト → Supabase Storage) | ✅ | `memo-image-upload` (VSCode版) |
| 11 | **ユーザーフィードバックパイプライン** (フォーム投稿→お礼メール+GH Issue+管理者一覧+スケジュール自動修正+リリース通知メール) | ✅ | `submit-feedback`, `notify-feature-request` |
| 12 | **コンソールエラー自動フィードバック投稿** (`FlutterError.onError` → `submit-feedback` EF に `type=auto_error` 自動送信) | ✅ | `submit-feedback` (VSCode版: `lib/utils/error_reporter.dart` + `main.dart`) |
| 13 | **思考妨害排除ガード** (デジタル/衝動/SNS 依存をブロック・断ち切り日数追跡 — 競合21社に存在しない唯一の機能) | ✅実装済・LP未訴求 | `lib/pages/abstinence_guard_page.dart` (VSCode版) |
| 14 | **ブログ記事実投稿パイプライン** (下書き自動生成済み → Zenn/Qiita/note への実投稿自動化) | 実装中 | `blog-post-manager`, `blog-auto-publisher` |

---

## 🎨 デザインシステム

- **`docs/DESIGN.md`** が唯一の真実ソース（Orange+Indigo ダークテーマ）
- **Figma MCP** / **AIDesigner MCP** / **`design-skills` サブエージェント** を活用
- 日本語本文: `letter-spacing: 0`, `line-height: 1.7〜2.0`, `palt` は見出しのみ
- 参考デザインシステム: `docs/design-systems/` (note / freee / SmartHR / Apple JP / WIRED.jp)

---

## 🛠 開発ルール（常時適用）

1. **`flutter analyze` 常に 0エラー** — CI強制ゲート（`continue-on-error` 禁止）
2. **`deno lint` 常に 0エラー** — CI強制ゲート（`denoland/setup-deno@v2`）
3. **`docs/GROWTH_STRATEGY_ROADMAP.md` を毎回更新** — セッション記録を末尾追記
4. **ダミーデータ禁止** — Supabase 実データ必須
5. **Edge Function ファースト** — 複雑ロジックはバックエンドに移動
6. **シンプルさ優先** — 依頼外機能の追加禁止
7. **EF上限管理** — Supabase 100本デプロイ上限 → 新規作成より既存EFへの `action` 追加優先。超える場合は Tier 2（コードのみ）に降格し `deploy-prod.yml` の Tier 2 コメントに記載
8. **毎セッション: 矛盾チェック（全インスタンス）** — 実装 (`lib/` / `supabase/functions/`) / 設計書 (`docs/DESIGN.md` / `docs/GROWTH_STRATEGY_ROADMAP.md`) / ユーザーマニュアル (`lib/pages/user_manual_page.dart`) を照合し、矛盾があれば修正する
9. **毎セッション: markdownlint（全インスタンス）** — `npx markdownlint-cli --dot "docs/**/*.md" ".github/**/*.md" "CLAUDE.md"` を実行し指摘があれば修正する（自動生成・アーカイブは `.markdownlintignore` で除外済み）
10. **毎セッション: docs/ .md 全件確認（全インスタンス）** — `docs/` 配下の全 .md ファイル（自動生成・アーカイブを除く）を読み、記載内容（数値・スコープ・機能名・ファイルパス）と現在の実装・CI設定との矛盾を修正する。対象: `CICD_SETUP_GUIDE.md` / `CONTRIBUTING.md` / `MULTI_INSTANCE_COORDINATION.md` / `README.md` / `DESIGN_TOOLING_SETUP.md` / `user-docs/*.md`

---

## ⚙️ GitHub Actions CI/CD（全13ワークフロー）

**全13本に完備済み**: `concurrency:` + `timeout-minutes:` + `$GITHUB_STEP_SUMMARY` + `permissions:`

| ワークフロー | トリガー | 特記事項 |
| --- | --- | --- |
| `ci.yml` | PR + push (main/staging/develop) | flutter analyze **強制** + deno lint **強制** + EF未分類警告 |
| `deploy-prod.yml` | push → main | CI再利用 + バージョン自動生成 + GitHub Release |
| `deploy-staging.yml` | push → staging | CI再利用 + staging channel デプロイ |
| `deploy-dev.yml` | push → develop | CI再利用 + dev channel デプロイ |
| `daily-report.yml` | 08:58 JST 毎日 | Supabase API + X投稿 + 競合モニタリング (Claude Scheduleの2分前) |
| `cs-check.yml` | 毎時 :07 | CS自動対応 + PR自動レビュー + ヘルスチェック |
| `edge-function-audit.yml` | 毎時 :47 | EF UI導線カバレッジチェック + GitHub Issue自動生成 (timeout 10分) |
| `infra-health-check.yml` | 毎時 :37 | Firebase + 重要EF 6件監視 |
| `cron-batch.yml` | 00:00 UTC 毎日 | Python分析バッチ (Gemini連携, `batch_analysis.py`) |
| `dependency-audit.yml` | 月曜 08:00 JST | `pub outdated` + Deno import バージョン固定チェック |
| `claude-agent-review.yml` | PR (main/staging/develop) | **Claude Managed Agents** — PRオープン即時AIレビュー (`ANTHROPIC_API_KEY` 必須) |
| `feedback-issue-resolved.yml` | issues: [closed] | `user-feedback` ラベル Issue クローズ → `notify-feature-request` EF でリリース通知メール |
| `workflow-failure-handler.yml` | workflow_run: [completed] | 主要10ワークフロー失敗時 → GitHub Issue自動生成 (`workflow-failure` ラベル) → `cs-check` が自動修復 |

**dependabot**: Actions + pub + pip を毎週月曜自動PR (`flutter-version: '3.38.x'`)

### CI/CD 品質基準（達成済み事項）

- アクション最新化: `codecov@v5` / `softprops/action-gh-release@v2` / `supabase-cli v2.84.2`
- セキュリティ: 読み取り専用4本に `persist-credentials: false` (edge-function-audit / dependency-audit / cron-batch / claude-agent-review) / `ci.yml` に Firebase/Google 認証ファイル検出
- 堅牢性: Slack webhook `--max-time 10 || true` / 全3環境の notify に `continue-on-error: true`
- ビルド統一: 全環境 `--no-tree-shake-icons` 適用
- EF 管理: Tier1=99本 厳守 (`notify-feature-request` Tier1 / `code-review-issues`, `user-growth-analytics` Tier2)
- **Claude Managed Agents 統合** (`claude-agent-review.yml`): static解析では検出できないルール違反・EF上限・アーキテクチャを PR 毎に自動レビュー
- **フィードバックパイプライン** (`feedback-issue-resolved.yml`): Issue クローズ → HTML comment から `feature_request_id`/`app_feedback_id` 抽出 → PR cross-reference 取得 → リリース通知メール

---

## ⏰ Claude Code Schedule タスク（9本）

> GitHub Actions と **並行・補完**する関係。Actions がデータ収集・投稿を担当し、Claude Schedule が AI分析・コード修正を担当。

| Task | 時刻 | 内容 |
| --- | --- | --- |
| `daily-report` | 09:00 JST | Actions生成レポート確認 → AI分析追記 → X投稿(失敗時のみ) → commit |
| `cs-check` | 毎時 | 未返信チケット → FAQ返信 / バグ修正 / エスカレーション → PR自動レビュー |
| `github-issue-fix` | 10:00 JST | Open Issue → EF UI導線追加 / analyze エラー修正 → クローズ |
| `weekly-sns-draft` | 月 09:00 | 週次SNSドラフト + Zenn記事ネタ + 依存脆弱性チェック |
| `pr-auto-review` | 3時間毎 | セキュリティ/パフォ/バグ観点のPRレビュー |
| `competitor-monitoring` | 07:00 JST | 競合21社の可用性 + 最新ニュース調査 |
| `infra-health-check` | 毎時 :30 | `health-check` EF + Firebase Hosting 確認 |
| `dependency-audit` | 月 08:00 | `pub outdated` + Deno import バージョン検査 |
| `blog-draft` | 08:00 JST | 直近7日コミット → ブログ下書き → `blog_posts` テーブル登録 |

---

## 🔑 環境変数（Schedule 実行時）

```text
SUPABASE_DIGEST_URL=https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
SUPABASE_SERVICE_KEY=<service_role key>
GITHUB_PAT=<repo + pull_requests スコープ>
```

X投稿先: **@kanta13jp1** (`post-x-update` EF, OAuth 1.0a 署名済み)

---

## 📁 主要ディレクトリ

```text
lib/pages/               # 193ページ (landing / comparison / user_manual / admin_analytics 等)
lib/widgets/             # 共通ウィジェット (edge_function_summary_card.dart 等)
supabase/functions/      # Deno Edge Functions 241本 (Tier1: 99デプロイ済 / Tier2: 142コードのみ)
supabase/migrations/     # YYYYMMDDXXXXXX_descriptive_name.sql
.github/workflows/       # 13本 (品質基準完備済み)
docs/
  GROWTH_STRATEGY_ROADMAP.md  # 全戦略・セッション記録 (毎回更新)
  DESIGN.md                   # デザイントークン (唯一の真実ソース)
  daily-reports/              # 日次レポート (GitHub Actions 生成)
  cs-notes/                   # CS チェックメモ
  weekly-drafts/              # 週次 SNS ドラフト
  blog-drafts/                # ブログ下書き
  competitor-reports/         # 競合モニタリング
  incident-reports/           # インシデントレポート
  security-audit/             # 脆弱性チェックレポート
web/index.html           # SEO meta tags
web/sitemap.xml          # URL マップ
```

---

## 📦 Edge Functions（Schedule連携 + 主要機能）

**Schedule連携 (必須)**:
`schedule-daily-digest` / `get-support-tickets` / `reply-support-request` / `get-home-dashboard` / `post-x-update` / `get-growth-roadmap-progress` / `get-competitor-features` / `health-check` / `check-competitor-updates`

**主要機能 EF**:
`guitar-recording-studio` / `local-election-intelligence` / `gemini-election-analysis` / `blog-post-manager` / `blog-auto-publisher` / `ai-assistant` / `daily-judgment` / `viral-video-generator` / `viral-growth-pipeline` / `development-achievements` / `edge-function-coverage` / `app-analytics-dashboard` / `submit-feedback` / `notify-feature-request`

> **Tier 1/2 管理**: `deploy-prod.yml` のデプロイリスト(99本) と Tier2コメント(142本) で全241本を追跡。CIの「EF未分類チェック」が漏れを検出（警告のみ / 未分類0本達成済み）。

---

## 🔜 実装待ち（他インスタンスへの指示）

### ~~機能 #12~~: ✅ 全インスタンス解決済み

- VSCode版: `lib/utils/error_reporter.dart` + `main.dart` `ErrorReporter.instance.install()` 実装済み
- Windows版: `supabase/migrations/20260410000700_add_is_auto_reported_to_feature_requests.sql` 作成済み

### ~~バグ #B1~~: ✅ 解決済み

全 `obscureText:` フィールド (4箇所) に `enableInteractiveSelection: true` + visibility toggle + paste ボタン適用済み:

- `emergency_meeting_page.dart` (APIキー)
- `morning_briefing_page.dart` (APIキー ×2)
- `landing_page.dart` (パスワード)

### ~~バグ #B3~~: ✅ 解決済み

`edge_function_status_page.dart` の「競合14社」→「競合21社」修正完了 (commit: VSCode#19)

### 機能 #13 (旧番): EF統合（action パラメーター分岐で99本以下に削減）

**背景**: Supabase 100本デプロイ上限 (現在99本運用)。今後の追加余地確保のため、類似 EF を `action` パラメーター分岐に統合する。

| インスタンス | 作業内容 |
| --- | --- |
| **Web版** | 類似機能の EF を `action` パラメーターで統合（例: `growth-acquisition-signal` + `growth-acquisition-report` → `growth-acquisition` EF に `action: "signal"\|"report"`）。優先統合候補: growth系23本・agent系12本。統合後は `deno lint` 0エラーを確認 |
| **PowerShell版** | Web版の統合完了後、`deploy-prod.yml` の Tier 1 リストから廃止 EF を削除し Cleanup ステップに追加、Tier 2 コメントを更新 |

### 機能 #15: 思考妨害排除ガードを LP 差別化訴求に追加（最優先）

**背景**: 2026-03-27 日次レポートで「競合21社に存在しない唯一の機能」と判定されたが、LP の「自分株式会社でしかできない8つのこと」に未掲載。`abstinence_guard_page.dart` は 1252行で完全実装済み。

| インスタンス | 作業内容 |
| --- | --- |
| **VSCode版** | `lib/pages/landing_page.dart` の `_buildUniqueValueSection()` に思考妨害排除ガードを9つ目として追加。文言例: `(Icons.block, '0xFFEF4444', '思考妨害排除ガード', 'SNS・ゲーム・衝動買いなどの依存を断ち切る専用モード。断ち切り日数を追跡。競合21社に存在しない唯一の機能。')` |

### 機能 #16: ブログ実投稿パイプライン完成

**背景**: `blog-draft` Schedule タスクで `docs/blog-drafts/` への下書き自動生成は稼働中。しかし Zenn/Qiita/note への実投稿は `blog_posts` テーブルの `status='draft'` のまま停滞している。

| インスタンス | 作業内容 |
| --- | --- |
| **Web版** | `blog-auto-publisher` EF を確認し、Zenn API または Zenn CLI 連携で `status='draft'` → `'posted'` に更新するフローを実装。まず Zenn CLI (`npx zenn`) を使った GitHub Actions 連携を検討する |

---

## 🤖 ゼロトークンリサーチ + Master Brain ワークフロー

**目的**: 重いドキュメント分析を Gemini に委譲して Claude のトークンを節約し、セッション間で学習を蓄積する。

### スラッシュコマンド

| コマンド | 定義ファイル | 用途 |
| --- | --- | --- |
| `/deep-research <トピック/ファイルパス>` | `.claude/commands/deep-research.md` | Gemini に分析委譲 → Claude が結果を整理 |
| `/wrap-up` | `.claude/commands/wrap-up.md` | セッション末尾: 学習を `memory/` に永続保存 |

### gemini_research.py

```bash
python gemini_research.py "質問テキスト"
python gemini_research.py --files file1.dart file2.ts --query "質問"
python gemini_research.py --url "https://..." --query "要約して"
python gemini_research.py --setup   # 接続テスト
```

- **MODEL_CASCADE**: `gemini-2.5-flash` → `gemini-2.5-pro` → `gemini-2.0-flash` → fallback
- **環境変数**: `GEMINI_API_KEY` が必要（`batch_analysis.py` と共通）
- **依存**: `requirements.txt` に `google-genai>=1.0.0,<2.0.0` 追記済み

### Master Brain (memory/)

保存先: `C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\`

| ファイルパターン | 内容 |
| --- | --- |
| `feedback_success_YYYYMMDD.md` | 成功パターン・承認されたアプローチ |
| `feedback_correction_YYYYMMDD.md` | 修正・禁止事項 |
| `project_YYYYMMDD.md` | 新規発見・プロジェクト固有の仕様 |

---

> **インスタンス別注意**: `docs/` と `supabase/migrations/` は **Windows版スコープ**。`supabase/functions/` は **Web版スコープ**。`lib/` は **VSCode版スコープ**。`.github/workflows/` は **PowerShell版スコープ**。
