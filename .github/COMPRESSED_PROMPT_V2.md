# 自分株式会社 統合プロンプト（圧縮版 v2）

## 🎯 ミッション

Flutter Web + Supabase で **21競合を統合するAIライフマネジメントアプリ** を構築。
本番: <https://my-web-app-b67f4.web.app/> / 実ユーザー: **4人** / **完成と言えるまで自己レビューを繰り返すこと**。

---

## 🔀 4インスタンス並行開発スコープ

| インスタンス | 担当範囲 | 変更禁止 |
|---|---|---|
| **VSCode版** | `lib/` (Flutter UI・194ページ・ウィジェット) | 他3範囲 |
| **Web版** | `supabase/functions/` (Edge Functions 238本) | 他3範囲 |
| **Windows版** | `docs/` + `supabase/migrations/` + seed SQL | 他3範囲 |
| **PowerShell版** | `.github/workflows/` + CI/CD (10本完備済み) | 他3範囲 |

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

| # | 機能 | 状態 | 主要EF |
|---|---|---|---|
| 1 | **競合機能比較ページ** (21社×機能マトリクス) | ✅ | `get-competitor-features` |
| 2 | **EF UI導線カバレッジ** (未接続→GitHub Issue自動生成) | ✅ | `edge-function-coverage` |
| 3 | **開発実績タイムライン** | ✅ | `development-achievements` |
| 4 | **ブログ自動投稿** (Zenn/Qiita/note/dev.to等, `blog_posts`テーブル管理) | ✅ | `blog-post-manager`, `blog-auto-publisher` |
| 5 | **モバイルギターレコーディングスタジオ** (H.264録画 + X自動シェア + AI演奏評価) | ✅ | `guitar-recording-studio` |
| 6 | **AI仮想秘書** (日次判定・タスク提案・スケジュール管理) | ✅ | `daily-judgment`, `ai-assistant` |
| 7 | **地方選挙インテリジェンス** (47都道府県×1年先×週末X投稿) | ✅ | `local-election-intelligence`, `gemini-election-analysis` |
| 8 | **バイラル動画パイプライン** (自動生成→投稿→効果測定) | 実装中 | `viral-video-generator`, `viral-growth-pipeline` |
| 9 | **Real Value YouTube競合分析** | 実装中 | (Python: `fetch_yt.py`) |

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
7. **EF上限管理** — Supabase 100本デプロイ上限 → 新規作成より既存EFへのaction追加優先。超える場合はTier 2（コードのみ）に降格し `deploy-prod.yml` の Tier 2コメントに記載

---

## ⚙️ GitHub Actions CI/CD（全10ワークフロー品質基準）

**全10本に完備済み**: `concurrency:` + `timeout-minutes:` + `$GITHUB_STEP_SUMMARY` + `permissions:`

**追加品質 (PS#28〜30)**:
- アクション最新化: `codecov@v5` / `softprops/action-gh-release@v2` / `supabase-cli v2.84.2`
- セキュリティ: 読み取り専用3本に `persist-credentials: false`
- 堅牢性: Slack webhook `--max-time 10 || true` / `requirements.txt` バージョン上限固定
- データ精度: `daily-report` fetch-depth `200` / `dependency-audit` Deno import `head -2000`

**追加品質 (PS#31〜35)**:
- セキュリティ強化: `ci.yml` に Firebase/Google 認証ファイル検出追加 + `.env.example` エスケープ修正
- コメント精度: `deploy-prod.yml` Tier2実数 (125→138) / `infra-health-check.yml` スケジュール誤記修正
- 権限修正: `deploy-dev.yml` ci ジョブに `contents: read` 追加 (staging と統一)
- 堅牢性: 全3環境の notify "Comment on commit" に `continue-on-error: true` 追加
- ビルド統一: `deploy-staging.yml` / `deploy-dev.yml` に `--no-tree-shake-icons` 追加 (prod/CI と統一)
- README修正: Flutter version v3.24→v3.38 / schedule_task_runs 7→6本 / dependabot pip追加

| ワークフロー | トリガー | 特記事項 |
|---|---|---|
| `ci.yml` | PR + push (main/staging/develop) | flutter analyze **強制** + deno lint **強制** + EF未分類警告 |
| `deploy-prod.yml` | push → main | CI再利用 + バージョン自動生成 + GitHub Release |
| `deploy-staging.yml` | push → staging | CI再利用 + staging channel デプロイ |
| `deploy-dev.yml` | push → develop | CI再利用 + dev channel デプロイ |
| `daily-report.yml` | 08:58 JST 毎日 | Supabase API + X投稿 + 競合モニタリング (Claude Scheduleの2分前) |
| `cs-check.yml` | 毎時 :07 | CS自動対応 + PR自動レビュー + ヘルスチェック |
| `edge-function-audit.yml` | 毎時 :47 | EF UI導線カバレッジチェック + GitHub Issue自動生成 |
| `infra-health-check.yml` | 毎時 :37 | Firebase + 重要EF 6件監視 |
| `cron-batch.yml` | 00:00 UTC 毎日 | Python分析バッチ (Gemini連携, `batch_analysis.py`) |
| `dependency-audit.yml` | 月曜 08:00 JST | `pub outdated` + Deno import バージョン固定チェック |

**dependabot**: Actions + pub + pip を毎週月曜自動PR (`flutter-version: '3.38.x'`)

---

## ⏰ Claude Code Schedule タスク（9本）

> GitHub Actions と **並行・補完**する関係。Actions がデータ収集・投稿を担当し、Claude Schedule が AI分析・コード修正を担当。

| Task | 時刻 | 内容 |
|---|---|---|
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

```
SUPABASE_DIGEST_URL=https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
SUPABASE_SERVICE_KEY=<service_role key>
GITHUB_PAT=<repo + pull_requests スコープ>
```

X投稿先: **@kanta13jp1** (`post-x-update` EF, OAuth 1.0a 署名済み)

---

## 📁 主要ディレクトリ

```
lib/pages/               # 194ページ (landing / comparison / user_manual / admin_analytics 等)
lib/widgets/             # 共通ウィジェット (edge_function_summary_card.dart 等)
supabase/functions/      # Deno Edge Functions 240本 (Tier1: 100デプロイ済 / Tier2: 140コードのみ)
supabase/migrations/     # YYYYMMDDXXXXXX_descriptive_name.sql
.github/workflows/       # 10本 (品質基準完備済み)
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
`guitar-recording-studio` / `local-election-intelligence` / `gemini-election-analysis` / `blog-post-manager` / `blog-auto-publisher` / `ai-assistant` / `daily-judgment` / `viral-video-generator` / `viral-growth-pipeline` / `development-achievements` / `edge-function-coverage` / `app-analytics-dashboard`

> **Tier 1/2 管理**: `deploy-prod.yml` のデプロイリスト(100本) と Tier2コメント(140本) で全240本を追跡。CIの「EF未分類チェック」が漏れを検出（警告のみ / 未分類0本達成済み）。

---

> **インスタンス別注意**: `docs/` と `supabase/migrations/` は **Windows版スコープ**。`supabase/functions/` は **Web版スコープ**。`lib/` は **VSCode版スコープ**。`.github/workflows/` は **PowerShell版スコープ**。
