# 自分株式会社 統合プロンプト（圧縮版 v3）

## 🎯 ミッション

Flutter Web + Supabase で **21競合を統合するAIライフマネジメントアプリ** を構築。
本番: <https://my-web-app-b67f4.web.app/> / 実ユーザー: **4人** / **完成と言えるまで自己レビューを繰り返すこと**。

---

## 🔀 4インスタンス並行開発スコープ

| インスタンス | 担当範囲 | 変更禁止 |
| --- | --- | --- |
| **VSCode版** | `lib/` (Flutter UI・195ページ・ウィジェット) | 他3範囲 |
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
| 7 | **地方選挙インテリジェンス** (47都道府県×1年先×週末X投稿) | ✅ LP済 | `local-election-intelligence`, `gemini-election-analysis` |
| 8 | **バイラル動画パイプライン** (自動生成→投稿→効果測定) | ✅ LP済 | `viral-video-ad-generator`, `x-media-post`, `viral-growth-engine` |
| 9 | **Real Value YouTube競合分析** | 実装中 | Python: `fetch_yt.py` |
| 10 | **メモ画像貼り付け** (Note/Notion風ドラッグ&ドロップ + クリップボードペースト → Supabase Storage) | ✅ | `memo-image-upload` (VSCode版) |
| 11 | **ユーザーフィードバックパイプライン** (フォーム投稿→お礼メール+GH Issue+管理者一覧+スケジュール自動修正+リリース通知メール) | ✅ | `submit-feedback`, `notify-feature-request` |
| 12 | **コンソールエラー自動フィードバック投稿** (`FlutterError.onError` → `submit-feedback` EF に `type=auto_error` 自動送信) | ✅ | `submit-feedback` (VSCode版: `lib/utils/error_reporter.dart` + `main.dart`) |
| 13 | **思考妨害排除ガード** (デジタル/衝動/SNS 依存をブロック・断ち切り日数追跡 — 競合21社に存在しない唯一の機能) | ✅ | `lib/pages/abstinence_guard_page.dart` (VSCode版) |
| 14 | **ブログ記事実投稿パイプライン** (下書き自動生成済み → Zenn/Qiita/note への実投稿自動化) | ✅ | `blog-post-manager`, `blog-auto-publisher` |
| 15 | **見栄ガード** (かっこつけない・見栄をはらない仕組み — 衝動的自己顕示を可視化・抑制) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 16 | **浪費トラッキング** (投資を除いた資産放出の記録・可視化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 17 | **12部署仮想組織 / AI秘書ゴール設定** (Slack・Chatwork・ジョブカン対抗軸) | ✅ LP済 | `AgentOrgPage` (VSCode版) |
| 18 | **コンビニ経営シミュレーション** (`conveni_stores` テーブル連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 19 | **友達招待 / 紹介コード** (ReferralShareCard — ホーム画面常設) | ✅ LP済 | `lib/widgets/` (VSCode版) |
| 20 | **ノートコメント + 絵文字リアクション + OGP シェア** (Notion/Evernote 対抗ソーシャル連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 21 | **通知センター** (NotificationsPage — `notification-center` EF 連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 22 | **電子署名** (法人・フリーランス向け — GitHub DocuSign 連携と直接競合) | ✅ LP済 | EF: `e-signature` 系 (Web版) |
| 23 | **集中タイマー** (ポモドーロ/ディープフォーカス — 思考妨害排除ガードと連携) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 24 | **AI文章アシスタント** (文章作成・推敲・要約) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 25 | **浪費耐性トレーニング** (浪費トラッキングと連携した行動変容トレーニング) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 26 | **語学学習** (フラッシュカード・発音練習・進捗管理) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 27 | **レシピ管理** (食材管理・献立提案・栄養分析) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 28 | **旅行計画** (行程管理・現地情報・費用管理) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 29 | **ペット管理** (健康記録・ワクチン管理・日記) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 30 | **フォトギャラリー** (AI分類・思い出管理・共有) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 31 | **マイAIエージェント** (ユーザー定義タスク自動化フロー — Notion Custom Agents 対抗) | ✅ LP済 | `lib/pages/ai_agent_page.dart` (VSCode版) + `my-ai-agent` EF (Web版) |
| 32 | **習慣ゲーミフィケーション** (ポイント・バッジ・ストリーク — Habitica 競合) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 33 | **コードプレイグラウンド** (ブラウザ内コード実行・学習環境) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 34 | **不動産管理** (物件管理・賃料追跡・投資分析) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 35 | **eラーニング** (コース管理・進捗・資格対策 — Duolingo/Udemy 競合) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 36 | **車両管理** (車検・保険・燃費・整備記録) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 37 | **採用ボード** (求職管理・応募追跡・面接スケジュール) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 38 | **IoTダッシュボード** (デバイス連携・センサーデータ可視化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 39 | **法務管理** (契約書管理・法的期限追跡) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 40 | **メールテンプレート管理** (ビジネス/プライベート定型文) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 41 | **2FA セキュリティ** (多要素認証強化 — セキュリティ差別化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 42 | **公開ギターギャラリー** (録音UGC公開共有 — sitemap/OGP済) | ✅ LP済 | `guitar-recording-studio` `public_gallery` action (VSCode版) |
| 43 | **月次カレンダービュー** (TableCalendar — スケジュール管理強化) | ✅ LP済 | `lib/pages/` (VSCode版) |
| 44 | **SaaSデータインポート** (Notion/Evernote/Markdown → 一括インポートUI+EF) | ✅ LP済 | `lib/pages/import_page.dart` (VSCode版) + `growth-import-preview`, `growth-import-commit` (Web版) |
| 45 | **アクティビティフィード** (行動ログ・達成記録タイムライン — Discord/Slack対抗) | ✅ LP済 | `lib/pages/activity_feed_page.dart` (VSCode版) |
| 46 | **報酬・達成バッジ** (ポイント・バッジ獲得ゲーミフィケーション) | ✅ LP済 | `lib/pages/rewards_page.dart` (VSCode版) |
| 47 | **支払いリマインダー** (月次サブスク・公共料金・ローン返済 — MoneyForward対抗) | ✅ LP済 | `lib/pages/payment_reminder_page.dart` (VSCode版) |

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
11. **セッション開始: Master Brain 参照（必須）** — `memory/MEMORY.md` を必ず読んで前回の成功パターン・禁止事項・発見を最初に把握する。「記憶が消える弱点」を永続メモリで補う
12. **重い分析は `/deep-research` 必須** — 3ファイル以上の同時分析・URL調査・競合リサーチ・大量ドキュメント俯瞰 → `python notebooklm_research.py` で NotebookLM に委譲。Claude は「判断・編集・統合」にこそトークンを使う。高負荷な分析を Google 側に無料で投げる
13. **セッション終了: `/wrap-up` 必須** — 作業完了後は必ず `/wrap-up` を実行して学習を `memory/` に永続保存。怠るとセッション間の記憶が消え、同じ失敗を繰り返す

---

## ⚙️ GitHub Actions CI/CD（全13ワークフロー）

**全13本に完備済み**: `concurrency:` + `timeout-minutes:` + `$GITHUB_STEP_SUMMARY` + `permissions:`

| ワークフロー | トリガー | 特記事項 |
| --- | --- | --- |
| `ci.yml` | PR + push (main/staging/develop) | flutter analyze **強制** + deno lint **強制** + EF未分類警告 |
| `deploy-prod.yml` | push → main | CI再利用 + バージョン自動生成 + GitHub Release |
| `deploy-staging.yml` | push → staging | CI再利用 + staging channel デプロイ |
| `deploy-dev.yml` | push → develop | CI再利用 + dev channel デプロイ |
| `daily-report.yml` | 07:30 JST 毎日 | Supabase API + X投稿 + 競合モニタリング (Claude Scheduleの1.5時間前) |
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
lib/pages/               # 195ページ (landing / comparison / user_manual / admin_analytics 等)
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
`guitar-recording-studio` / `local-election-intelligence` / `gemini-election-analysis` / `blog-post-manager` / `blog-auto-publisher` / `ai-assistant` / `daily-judgment` / `viral-video-generator` / `viral-growth-pipeline` / `development-achievements` / `edge-function-coverage` / `app-analytics-dashboard` / `submit-feedback` / `notify-feature-request` / `notification-center` / `onboarding-flow` / `seo-optimizer` / `ab-testing-manager` / `competitor-feature-sync` / `user-activity-tracker` / `webhook-manager` / `data-export-manager` / `viral-video-ad-generator` / `x-media-post` / `viral-growth-engine` / `viral-share-engine`

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

### ~~バグ #B4~~: ✅ 解決済み (Web版#26, 2026-04-10)

`note-comments/index.ts` の `getUserIdFromJwt()` (署名未検証) を削除し、`client.auth.getUser()` による正式JWT署名検証に置き換え。`deno lint` 0エラー確認済み。

### ~~機能 #13~~: ✅ 全インスタンス解決済み (Web版#28 + PowerShell版#20, 2026-04-11)

- Web版: `growth-acquisition/index.ts` 新規作成。`growth-acquisition-signal` + `growth-acquisition-report` を `action: "signal"|"report"` 分岐で統合。`deno lint` 0エラー確認。
- PowerShell版: `deploy-prod.yml` Tier 1B から旧2本を削除し `growth-acquisition` + `my-ai-agent` を追加。Cleanup step に削除コマンド追加。Tier 2 コメントに旧2本を記録。

### ~~機能 #15~~: ✅ 解決済み (VSCode#23, 2026-04-10)

`lib/pages/landing_page.dart` `_buildUniqueValueSection()` に9つ目として追加。タイトル「9つのこと」に更新。コミット `ffc849bd`。

### ~~機能 #16~~: ✅ 解決済み (Web版#27, 2026-04-11)

`blog-auto-publisher` EF に Qiita API (`publish_qiita`) / dev.to API (`publish_devto`) / `auto_publish` アクションを実装。`blog_posts.status` を `draft→posted` に自動更新。`CLAUDE.md` の blog-draft Schedule タスクに Step 4 (auto_publish 呼び出し) を追加。Supabase シークレット: `QIITA_ACCESS_TOKEN` / `DEVTO_API_KEY` を設定すれば即稼働。

### ~~機能 #17~~: ✅ 解決済み (VSCode#24, 2026-04-11)

見栄ガード・浪費トラッキングを `_buildUniqueValueSection()` に追加。

### ~~機能 #18~~: ✅ 解決済み (VSCode#24, 2026-04-11)

12部署AI仮想組織を `_buildUniqueValueSection()` に追加。

### ~~機能 #19~~: ✅ 解決済み (VSCode#24, 2026-04-11)

友達招待・紹介コードを `_buildUniqueValueSection()` に追加。

### ~~機能 #20~~: ✅ 解決済み (VSCode#24, 2026-04-11)

ノートコメント・リアクション・OGP シェアを `_buildUniqueValueSection()` に追加。タイトル「14のこと」に更新。

### ~~機能 #21~~: ✅ 解決済み (VSCode#25, 2026-04-11)

通知センターを `_buildUniqueValueSection()` に追加。

### ~~機能 #22~~: ✅ 解決済み (VSCode#25, 2026-04-11)

電子署名を `_buildUniqueValueSection()` に追加。タイトル「16のこと」に更新。

### ~~機能 #23~~: ✅ 解決済み (VSCode#26, 2026-04-11)

コンビニ経営シミュレーションを `_buildUniqueValueSection()` に追加 (Icons.storefront)。タイトル「17のこと」に更新。コア機能リスト #15〜#22 のステータスを「LP未訴求 → LP済」に一括更新。

### ~~docs/ リンク修正~~: ✅ 解決済み (Windows版#18, 2026-04-11)

- `docs/technical/BRANCH_PROTECTION_SETUP.md` 新規作成 (ブランチ保護設定手順・CI連携・Claude Schedule との関係を記載)
- `LICENSE` ファイルをリポジトリルートに作成 (MIT License, 2025-2026 kanta13jp1)
- markdownlint 0エラー確認 (COMPRESSED_PROMPT_V3.md MD012 連続空行1件修正)

### ~~機能 #24~~: ✅ 解決済み (VSCode#27, 2026-04-11)

集中タイマー (Icons.timer) + AI文章アシスタント (Icons.edit_note) を `_buildUniqueValueSection()` に追加。

### ~~機能 #25~~: ✅ 解決済み (VSCode#27, 2026-04-11)

浪費耐性トレーニング (Icons.fitness_center) を `_buildUniqueValueSection()` に追加。タイトル「17のこと」→「20のこと」に更新。コア機能リスト #23〜#25 LP済に更新。

### ~~機能 #26~~: ✅ 解決済み (VSCode#28, 2026-04-11)

語学学習・レシピ管理・旅行計画・ペット管理・フォトギャラリー + バイラル動画パイプラインを LP 追加。タイトル「20のこと」→「26のこと」。コア機能リスト #8 LP済に更新。

### ~~機能 #31~~: ✅ 解決済み (VSCode#28 + Web版#28, 2026-04-11)

- VSCode版: `lib/pages/ai_agent_page.dart` 作成済み — タスク自動化フロー定義 UI + `/my-ai-agent` ルート追加
- Web版: `my-ai-agent` EF 作成済み — create/update/delete/run/list アクション実装。ステップ種別: ai_chat (Anthropic API) / http_request / send_notification / supabase_insert

### ~~機能 #32~~: ✅ 解決済み (VSCode#29, 2026-04-11)

**背景**: 2026-04-04 日次レポートで確認。PS#15・VSCode#1・VSCode#2で実装済みの10機能が LP 未掲載。

| インスタンス | 作業内容 |
| --- | --- |
| ~~**VSCode版**~~ | ✅ `landing_page.dart` に10機能追加 (VSCode#29) — 習慣ゲーミフィケーション・コードプレイグラウンド・不動産管理・eラーニング・車両管理・採用ボード・IoT・法務・メールテンプレート・2FA。"36のこと"に更新 |

### 機能 #44: SaaSデータインポート UI 実装

**背景**: 2026-04-08 AI分析で `growth-import-preview` / `growth-import-commit` EF が実装済みと確認。ユーザーリクエスト上位「Notion インポート強化」に対応するフロントエンド UI が未実装。

| インスタンス | 作業内容 |
| --- | --- |
| ~~**VSCode版**~~ | ✅ 既実装確認 (VSCode#30) — `lib/pages/import_page.dart` + `/import` ルート + `growth-import-preview` EF 呼び出し済み |
| **Web版** | `growth-import-preview` に Notion API 連携を追加 (現状は汎用スタブ) |

### CI/CD改善 #C1: 2026-03-27 日次レポート分析からの反映 (PowerShell版#21, 2026-04-11)

**背景**: 2026-03-27 レポートで「競合監視3社のみ」「X投稿リトライなし」「Supabase API接続ブロック」が課題として確認。

| 課題 | 対応 | ステータス |
| --- | --- | --- |
| Supabase API接続ブロック (エグレスプロキシ) | `daily-report.yml` を GitHub Actions に移管し07:30 JSTに先行実行 | ✅ 解決済み (PS#19) |
| 競合監視が3社のみ (Notion/Evernote/Slack) | 7社に拡大: Slack/GitHub/Notion/Evernote/Discord/LINE/X | ✅ 解決済み (PS#21) |
| X投稿失敗時のリトライなし | 失敗時に20秒後1回リトライを追加 | ✅ 解決済み (PS#21) |
| ユーザー数4人で停滞 (2026-03-27〜2026-04-11) | LP機能追加・Zenn/Qiita自動投稿稼働中 → 継続監視 | 🔄 対応中 |

> ✅ **Windows版#21 対応済み**: `GROWTH_STRATEGY_ROADMAP.md` にユーザー獲得停滞緊急度を記録。
> 「Zenn/Qiita記事実投稿」は **パイプライン完成・下書き6本蓄積済み・シークレット未設定** と確認 → 機能 #45 として計画化。

### 機能 #45: 技術記事の実投稿実行 (最優先・即実行可能)

**背景**: 2026-03-27 レポートで「Zenn/Qiita記事の即日公開がユーザー獲得の最優先施策」と提言。パイプライン (`blog-auto-publisher`) が完成した今こそ実行フェーズ。

**現状**:

- 下書き6本が `docs/blog-drafts/2026-03-27-*.md` に存在 (Zenn/Qiita/dev.to/note/Medium/はてな)
- `blog-auto-publisher` EF の `auto_publish` アクション実装済み
- **ブロッカー**: Supabase シークレット 2件が未設定

**必要作業**:

| 担当 | 作業 |
| --- | --- |
| **ユーザー (手動)** | Supabase ダッシュボード → Edge Functions → Secrets に `QIITA_ACCESS_TOKEN` / `DEVTO_API_KEY` を追加 |
| **Web版 or 任意** | `blog-auto-publisher` EF の `auto_publish` を呼び出し `docs/blog-drafts/2026-03-27-zenn-schedule-automation.md` を Zenn CLI 経由で投稿 (Zenn は GitHub 連携のため手動) |
| **Web版 or 任意** | シークレット設定後に `publish_qiita` アクションで `2026-03-27-qiita-schedule-setup.md` を Qiita に投稿 |

**推定ROI**: #buildinpublic / #FlutterWeb / #Supabase タグで開発者コミュニティに到達 → ユーザー4人からの脱却。

### CI/CD改善 #C2: 2026-03-28 日次レポート分析からの反映 (PowerShell版#22, 2026-04-11)

**背景**: 2026-03-28 は GitHub Actions 移行当日。cs-check が「PR経由コミット」で実装されたが、ブランチ名衝突・push rejected が頻発 (commit #234/#235)。daily-report.yml は PS#19 で直接 push 化済みだが cs-check.yml は未対応だった。

| 課題 | 対応 | ステータス |
| --- | --- | --- |
| cs-check.yml のブランチ作成→PR→マージフロー (39行) | `git push origin HEAD:main` に簡略化 (daily-report.yml と統一) | ✅ 解決済み (PS#22) |
| 12部署仮想組織 & EdgeFunctionSummaryCard の LP 掲載 | LP 実装済み (機能 #17 / VSCode#24) | ✅ 解決済み |

### ユーザーリクエスト上位 (2026-04-08 確認 / 未対応)

> feature_requests 投票上位。優先度順に実装検討する。

1. **Notion インポート強化** — Notion ページ階層・データベース構造インポート (EF実装済み → UI + Notion API 連携が必要)
2. **MoneyForward 連携** — 家計簿・資産管理データ自動取り込み
3. **Slack 通知連携** — タスク・メモ更新を Slack チャンネルへ通知
4. **モバイルアプリ (iOS/Android)** — Flutter モバイルビルド対応
5. **Google カレンダー同期** — 予定・タスクの双方向同期

---

## 🤖 ゼロトークンリサーチ + Master Brain ワークフロー

**目的**: 重いドキュメント分析を NotebookLM に委譲して Claude のトークンを節約し、セッション間で学習を蓄積する。

### スラッシュコマンド

| コマンド | 定義ファイル | 用途 |
| --- | --- | --- |
| `/deep-research <トピック/ファイルパス>` | `.claude/commands/deep-research.md` | NotebookLM に分析委譲 → Claude が結果を整理 |
| `/wrap-up` | `.claude/commands/wrap-up.md` | セッション末尾: 学習を `memory/` に永続保存 |

### notebooklm_research.py

```bash
python notebooklm_research.py "テキスト"
python notebooklm_research.py --files file1.dart --query "質問"
python notebooklm_research.py --url "https://..." --query "要約して"
python notebooklm_research.py --setup
```

- **バックエンド**: Google NotebookLM (notebooklm-py 経由)
- **認証**: notebooklm login でブラウザ Google 認証
- **フロー**: 一時ノートブック作成 → ソース追加 → Q&A → ノートブック削除
- **依存**: requirements.txt に notebooklm-py>=0.1.0 追記済み
- **注意**: 非公式ライブラリ。undocumented Google API 使用のため突然の仕様変更あり

### Master Brain (memory/)

保存先: `C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\`

| ファイルパターン | 内容 |
| --- | --- |
| `feedback_success_YYYYMMDD.md` | 成功パターン・承認されたアプローチ |
| `feedback_correction_YYYYMMDD.md` | 修正・禁止事項 |
| `project_YYYYMMDD.md` | 新規発見・プロジェクト固有の仕様 |

---

> **インスタンス別注意**: `docs/` と `supabase/migrations/` は **Windows版スコープ**。`supabase/functions/` は **Web版スコープ**。`lib/` は **VSCode版スコープ**。`.github/workflows/` は **PowerShell版スコープ**。
