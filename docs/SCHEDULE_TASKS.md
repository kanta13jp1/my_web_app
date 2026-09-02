# Schedule タスク (Claude Code Schedule 自動化)

> 旧 CLAUDE.md から分離 (Win版#131 part 6・2026-04-20)。
> CLAUDE.md 圧縮のため Schedule 自動化タスク全件を本ファイルに移管。
> 元の Schedule タスクは Claude Code Schedule (定期実行) 用の指示。
> SCHEDULE_TASK 環境変数で実行するタスクを判別する。

## Claude Code Schedule 自動化タスク

> **注意**: 以下のタスクは Claude Code Schedule (定期実行) 用の指示です。
> スケジュール実行時は、下記の SCHEDULE_TASK 環境変数で実行するタスクを判別してください。

### 環境変数 (スケジュール実行時に必要)

```text
SUPABASE_DIGEST_URL=https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
SUPABASE_SERVICE_KEY=<Supabase service_role key>
GITHUB_PAT=<GitHub Personal Access Token (repo + pull_requests スコープ)>
```

### X アカウント

X への自動投稿先: **@kanta13jp1**
投稿は `post-x-update` Edge Function 経由 (OAuth 1.0a で署名済み)

---

### Task: feature-review (毎時 0 分 / 13 機能 round-robin)

**起源**: Win版#132 part 77-78 / Handoff Bundle 第 1 適用例
**Workflow**: `.github/workflows/feature-review.yml`
**Script**: `scripts/feature_review.py`
**Config**: `scripts/feature_review_config.json`

13 機能 (= 9 page + 4 Edge Function) を毎時 1 機能ずつレビューし、修正すべき問題を `auto-review` GitHub Issue として自動起票する。

- 通常 cron: `UTC hour % 13` で対象機能を 1 件選択
- 手動実行: `target_features` で対象指定、または `force_full_scan=true` で全件 audit
- throttle: max 3 issues/run、max 1 issue/feature
- de-dupe: `[review:<hash>]` title hash で open issue と直近 closed issue を skip
- Slack: 新規 issue がある run のみ `SLACK_WEBHOOK_URL` に集計通知

---

### Task: daily-report (毎朝 09:00 JST に実行)

> **アーキテクチャ**: GitHub Actions `daily-report.yml` が 07:30 JST に先行実行し、
> Supabase API 取得・X投稿・競合モニタリングを行う（プロキシ制限なし）。
> Claude Schedule (09:00 JST) はその結果を読み込み、AI分析・GitHub Issue修復・
> Schedule健全性チェックを担当する。

以下のステップを順番に実行してください:

#### Step 1: GitHub Actions 生成済みレポートを確認・データ取得

まず今日付のレポートが GitHub Actions によって既に生成されているか確認する:

```bash
# 今日のレポートファイルが存在するか確認
ls docs/daily-reports/YYYY-MM-DD.md 2>/dev/null

# 推奨: レポート・schedule-log・metrics の複数シグナルで確認する
git fetch origin main --quiet
python scripts/check_daily_report_freshness.py --date YYYY-MM-DD --ref origin/main --json
```

**ケース A: ファイルが存在し `<!-- generated-by: github-actions -->` または `<!-- generated-by: claude-schedule -->` を含む場合**

Read ツールでファイルを読み込み、概要セクション（ユーザー数・リクエスト数等）を
そのまま利用する。Step 3・Step 4 は Actions 実施済みとしてスキップ可。

> 誤検知防止: `git log --author='Claude Schedule'` だけで未実行判定しないこと。
> GitHub Actions / Claude Schedule / 復旧ジョブのどれが完了させても、
> `docs/daily-reports/YYYY-MM-DD.md` と `docs/schedule-logs/daily-report-YYYY-MM-DD-00.json`
> を正本として扱う。

**ケース B: ファイルが存在しない場合（Actions 未実行 or 失敗）**

以下の Supabase API を試みる（Claude Code Web 環境ではプロキシにより失敗する場合がある）:

```http
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
Authorization: Bearer <SUPABASE_SERVICE_KEY>
```

失敗した場合は git log ベースのフォールバックレポートを生成する。

#### Step 2: 日次レポートを生成・保存 (AI分析を付加)

ファイルパス: `docs/daily-reports/YYYY-MM-DD.md`

- ケース A: Actions 生成ファイルの末尾に `## AI分析 (Claude Schedule)` セクションを追記
- ケース B: 以下フォーマットで新規作成

```markdown
# 自分株式会社 日次レポート YYYY-MM-DD

## 概要
- **総ユーザー数**: {users.total}人
- **本日の新規機能リクエスト**: {featureRequests.newToday}件
- **未対応機能リクエスト**: {featureRequests.openCount}件

## 本日の新規機能リクエスト
{newTodayList が空でない場合: リスト表示。空の場合: "なし"}

## 注目の未対応リクエスト (投票数上位)
{topOpen を投票数順にリスト表示}

## 直近の開発実績
{recentAchievements をリスト表示}

## 競合動向
{Actions が実施済みの場合はスキップ。未実施の場合はフォールバック記録}

## AI分析 (Claude Schedule)
AIとして、上記データを踏まえた優先対応事項を3点提案する。
特に投票数の多い機能リクエストや、ユーザー成長に繋がるアクションを優先。
```

#### Step 3: X (Twitter) に投稿

> **注意**: Actions 生成レポートに `## X投稿` セクションがあり `✅ 投稿成功` と記載されている場合はスキップ。

Actions が失敗 or 未実行の場合のみ実行:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/post-x-update
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{ "text": "<140字以内. カジュアルトーン. #buildinpublic #FlutterWeb>" }
```

#### Step 4: 競合モニタリング

> **注意**: Actions 生成レポートに `## 競合動向` セクションがある場合はスキップ。

Actions が失敗 or 未実行の場合のみ WebFetch で Notion / Evernote / Slack を確認し、
`## 競合動向` セクションとして記録する。

#### Step 5: コミット

```bash
git add docs/daily-reports/YYYY-MM-DD.md
git commit -m "自動: 日次レポート YYYY-MM-DD"
git push origin main
```

---

### Task: cs-check (毎時 実行)

CS対応・バグ修正・エスカレーションを完全自動化する。

#### Step 1: 未返信チケットを取得

WebFetch で以下を呼び出す:

```http
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/get-support-tickets
Authorization: Bearer <SUPABASE_SERVICE_KEY>
```

レスポンスから `tickets` (未返信) と `faq` (FAQ一覧) を取得する。
チケットが0件なら処理を終了（コミット不要）。

#### Step 2: 各チケットを判断・対応

チケットごとに以下を判断する:

#### ケース A: FAQ で答えられる

- `faq` 一覧と照合し、類似する質問が見つかれば FAQ の回答を参考に返信文を生成
- POST で返信:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/reply-support-request
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{ "id": "<ticket_id>", "reply": "<返信文(日本語)>", "newStatus": "open" }
```

#### ケース B: バグの可能性がある (タイトル・説明に「動かない」「エラー」「できない」「バグ」等)

1. 関連する Dart/TypeScript ソースを `lib/` または `supabase/functions/` から読んで原因を特定
2. 修正可能な軽微なバグ（typo、null チェック漏れ、ロジック誤りなど）であれば:
   a. コードを修正（**Edit ツールで局所修正**。`sed` / heredoc で全文上書きしない。
      文字列補間 `${expr}` / `$var` の `$` を**絶対にエスケープしない** —
      `$`→`\$` 過剰エスケープは compile 不能化の典型バグ。2026-06-25 incident 参照）
   b. **検証ゲート (必須)**: 変更ファイルを analyzer へ通し 0 エラーを確認。
      Dart → `dart analyze <変更ファイル>`（全体は OOM のため変更ファイルのみ） /
      TypeScript → `deno check <変更ファイル>`。
      早期検知 → `grep -nF '\${' <変更ファイル>` で `\${` を見つけたら過剰エスケープ。
      0 エラーでなければ commit しない。
   c. `git add -p && git commit -m "fix: <バグ内容>" && git push origin main` でコミット
      （**analyzer を実行できない実行環境 (例: WEB版 sandbox) では main へ直接 push 禁止。
      PR を作り ci.yml にゲートさせる**）
   d. 返信文に「修正しました。本番デプロイまで数分お待ちください」と記載して返信
3. 複雑な修正が必要な場合はエスカレーション (ケース C)

#### ケース C: 返金・課金・退会・緊急 or 判断困難

- エスカレーションとしてマーク:

```json
{ "id": "<ticket_id>", "escalate": true }
```

- `docs/cs-notes/YYYY-MM-DD-HH.md` にエスカレーション内容を記録

#### Step 3: CS ノートを記録してコミット

対応内容の記録を `docs/cs-notes/YYYY-MM-DD-HH.md` に保存:

```markdown
# CS チェック YYYY-MM-DD HH:00

## 対応済み (FAQ返信)
- [タイトル] → 返信送信

## 対応済み (バグ修正)
- [タイトル] → 修正コミット: <commit hash>

## エスカレーション (要人間対応)
- [タイトル] → 理由: <判断できなかった理由>

## スキップ (投票0・重複など)
- なし
```

コミット:

```bash
git add docs/cs-notes/
git commit -m "自動: CS チェック YYYY-MM-DD HH:00"
git push origin main
```

チケットが0件 or 全てスキップの場合はコミット不要。

#### Step 4: GitHub PR レビュー (GITHUB_PAT が設定されている場合)

```bash
gh pr list --state open --json number,title,additions,deletions,files
```

各PRに対して以下の観点でコードレビューを実施:

- セキュリティ (SQL injection, XSS, 認証漏れ)
- パフォーマンス (N+1クエリ、不要な再レンダリング)
- Lintエラー・型エラー
- CLAUDE.md のルール違反 (ダミーデータ使用、flutter analyze エラーなど)

指摘がある場合は `gh pr comment <number> --body "<レビューコメント>"` で投稿。
既にコメント済みの内容は重複投稿しない。

#### Step 5: インフラ・ヘルスチェック

以下のエンドポイントを WebFetch で確認し、異常があれば cs-notes に記録する:

```http
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/get-home-dashboard
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/development-achievements
GET https://my-web-app-b67f4.web.app/
```

- HTTP 200 以外のレスポンス → `docs/cs-notes/YYYY-MM-DD-HH.md` の末尾に `## インフラ異常` として記録
- タイムアウト (10秒以上) も異常として記録
- 全て正常なら記録不要

---

### Task: self-devin-schedule (daily 09:30 JST)

Routes the next pending WBS feature request into the existing autonomous repair lane.

1. Read pending WBS tasks from `tools-hub:wbs.list_tasks`.
2. Pick the next task whose title/category includes `追加要望`.
3. Mark the task `in_progress`.
4. If the task description has a GitHub Issue URL:
   - closed Issue -> mark WBS task `completed`
   - open Issue -> dispatch `.github/workflows/github-issue-fix.yml`
5. If no Issue URL exists, create a GitHub Issue and dispatch the same repair workflow.
6. Record the result in `schedule_task_runs` as `self-devin-schedule`.

Manual run:

```bash
gh workflow run self-devin-schedule.yml -f dry_run=true
gh workflow run self-devin-schedule.yml -f wbs_task_id=<task-id> -f dry_run=false
```

---

### Task: github-issue-fix (毎日 10:00 JST に実行)

GitHub Issues を自動チェックし、修正可能なものを自動対応する。

#### Step 1: オープンIssueを取得

```bash
gh issue list --state open --json number,title,body,labels --limit 30
```

#### Step 2: 各Issueを判断・対応

**ケース A: Edge Function UI導線チェック (`[自動] Edge Function UI導線チェック`)**

- Issue body から未接続の Edge Function 名リストを抽出
- `lib/widgets/edge_function_summary_card.dart` を読んで、既に追加済みかを確認
- 未追加の場合: `edge_function_summary_card.dart` の関数リストに追加
- `flutter analyze` で0エラーを確認後、コミット
- Issue に対して解決コメントを投稿: `gh issue comment <number> --body "✅ UI接続を追加しました。コミット: <hash>"`
- Issue をクローズ: `gh issue close <number>`

**ケース B: flutter analyze エラー (`[自動] flutter analyze`)**

- エラー内容を読んで、修正可能なら修正
- `flutter analyze` で0エラーを確認後、コミット・クローズ

**ケース C: 判断困難または手動対応が必要**

- `docs/cs-notes/YYYY-MM-DD-github-issues.md` にメモを残す
- Issue はそのまま維持

#### Step 3: コミット・プッシュ

```bash
git add -A
git commit -m "fix: GitHub Issue 自動対応 YYYY-MM-DD"
git push origin main
```

変更がない場合はコミット不要。

---

### Task: weekly-sns-draft (毎週月曜 09:00 JST に実行)

#### Step 1: 先週の実績サマリーを生成

`docs/daily-reports/` の直近7日分を読み込み、週次サマリーを作成:

ファイルパス: `docs/weekly-drafts/YYYY-MM-DD-week.md`

```markdown
# 週次 SNS 投稿ドラフト (YYYY-MM-DD 週)

## X (Twitter) 投稿ドラフト (140字以内)

[ドラフト1: ユーザー数の進捗]
自分株式会社、今週もビルド継続中🚀
現在 {users.total}人が使用中。
14の競合SaaSを超えるAI統合アプリを無料で体験:
https://my-web-app-b67f4.web.app/ #buildinpublic

[ドラフト2: 機能開発の進捗]
今週実装した機能: {直近の実績タイトルを2-3個}
コツコツ積み上げ中💪 #FlutterWeb #Supabase

## Zenn 記事ネタ提案
1. {今週の実装内容から技術記事ネタを3つ提案}
```

#### Step 2: 依存パッケージの脆弱性チェック

`pubspec.yaml` と `supabase/functions/` の deno import URLを読み込み、以下を確認:

- 古いバージョンのパッケージ (メジャーバージョンが2以上古い)
- 既知の脆弱性パターン (CVEなど)

問題があれば週次ドラフトに `## 依存パッケージ注意` セクションを追加して記録する。

コミット:

```bash
git add docs/weekly-drafts/
git commit -m "自動: 週次SNSドラフト YYYY-MM-DD"
```

---

### Task: pr-auto-review (3時間ごとに実行)

GitHub PRの自動コードレビュー。

1. `gh pr list --state open` でオープンPRを確認
2. 各PRの差分を取得し、パフォーマンス・ロジックバグの観点でレビュー
3. 指摘があれば `gh pr review` でコメント投稿
4. 問題なければ approve
5. **CI失敗PR対応**: `ci-auto-fix.yml` が `dart fix --apply` + `deno fmt` を自動適用済みの場合は
   その結果コメントを確認し、残存エラーがあれば追加コメントで手動修正を促す。
   `ci-auto-fix.yml` 未実行の場合は `gh run list --branch <branch>` で CI ログを確認して
   修正可能なエラー (deprecated API / import typo 等) があればコードを直接修正してコミット。

---

### Task: security-audit (毎週月曜 07:17 JST に実行)

`pr-auto-review` とは独立して `.github/workflows/security-audit.yml` を実行する。
GitHub Actions の最小権限・依存供給網、migration 順序、認証済み decision-event API を監査する。
高リスク PR は `.github/workflows/high-risk-dual-security-review.yml` で Claude と Codex を
独立実行し、fallback は二重レビューとして数えない。片方の API credential または
decision-event 永続化が利用できない場合は、PR に例外 evidence を残して fail closed とする。
Codex lane は静的な OpenAI API key を保存せず、GitHub OIDC から OpenAI Workload
Identity Federation で短期 token を取得する。管理画面設定と復旧手順は
[`OPENAI_WIF_SECURITY_REVIEW_RUNBOOK.md`](OPENAI_WIF_SECURITY_REVIEW_RUNBOOK.md) を参照する。

---

### Task: competitor-monitoring (毎日 07:00 JST に実行)

競合21社のWebサイト・機能変更モニタリング。

1. `check-competitor-updates` Edge Function で可用性チェック
2. WebSearch で各競合の最新ニュースを検索
3. `docs/competitor-reports/YYYY-MM-DD.md` にレポート作成
4. 重要な変更があれば GROWTH_STRATEGY_ROADMAP.md にも反映

---

### Task: infra-health-check (毎時30分に実行)

インフラヘルスチェック。

1. `health-check` Edge Function で DB・テーブル・レスポンスタイムを確認
2. Firebase Hosting (<https://my-web-app-b67f4.web.app/>) の可用性を確認
3. 異常時のみ `docs/incident-reports/YYYY-MM-DD-HH.md` にレポート作成

---

### Task: dependency-audit (毎週月曜 08:00 JST に実行)

依存パッケージの脆弱性チェック。

1. `flutter pub outdated` で古いパッケージを確認
2. Deno Edge Functions の import URL バージョンを確認
3. 脆弱性があればパッチ更新 or レポート作成 (`docs/security-audit/YYYY-MM-DD.md`)
4. `flutter analyze` と `deno lint` で0エラーを確認

---

### Task: blog-draft (毎日 08:00 JST に実行)

技術ブログの下書きを生成し、投稿管理テーブルに記録する。

#### Step 1: 直近の開発内容を確認

```bash
git log --oneline --since="7 days ago"
```

直近7日間のコミット一覧を取得する。

#### Step 2: ブログ下書きを生成・保存 (日本語 + 英語の2ファイル)

**日本語版** (Qiita 投稿用): `docs/blog-drafts/YYYY-MM-DD.md`

```markdown
---
title: "{実装内容を技術的に面白く表現したタイトル}"
tags: Flutter,Supabase,buildinpublic,個人開発
published: false
---

# {タイトル}

## はじめに
{なぜこの機能を作ったか、どんな課題を解決するか}

## 実装方法
{Flutter/Supabase での具体的な実装手順、コードスニペット付き}

## 詰まったポイント
{実際にハマった部分と解決策}

## まとめ
{今後の展望、リポジトリ/サービスへのリンク}

---
自分株式会社: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発
```

**英語版** (dev.to 投稿用): `docs/blog-drafts/YYYY-MM-DD-en.md`

```markdown
---
title: "{English title — same technical content}"
tags: Flutter,Supabase,buildinpublic,webdev
published: false
---

# {English Title}

## Introduction
{Why this feature was built, what problem it solves}

## Implementation
{Flutter/Supabase step-by-step, with code snippets}

## Challenges
{What was tricky and how it was solved}

## Conclusion
{Next steps, links}

---
Building in public: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic
```

> **注意**: 日本語版と英語版は同じ技術内容を扱うが、それぞれの文化・読者に合わせた表現で書くこと。英語版は dev.to の読者向けに direct/concise なスタイルで。

#### Step 3: 投稿記録をSupabaseに保存 (`blog-post-manager` EF)

`blog-post-manager` EF の POST で `blog_posts` テーブルに下書きを登録:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/blog-post-manager
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{
  "title": "<タイトル案1>",
  "draft_path": "docs/blog-drafts/YYYY-MM-DD.md",
  "target_platforms": ["qiita", "devto"],
  "content_preview": "<本文最初の200字>"
}
```

レスポンスの `post.id` (UUID) を Step 4 で使用する。

※ `blog_posts` テーブルのスキーマ:

```sql
id uuid, title text, draft_path text, status text (draft/posted/skipped),
target_platforms text[], posted_at timestamptz, url text, created_at timestamptz
```

#### Step 4: 自動投稿 (`blog-auto-publisher` EF)

Step 3 で登録した `post.id` と本文全体を使って実投稿:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/blog-auto-publisher
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{
  "action": "auto_publish",
  "id": "<post.id>",
  "content": "<本文下書きのMarkdown全文>",
  "tags": ["Flutter", "Supabase", "buildinpublic"]
}
```

**投稿先と必要なシークレット**:

| プラットフォーム | Supabaseシークレット | 設定方法 |
| --- | --- | --- |
| Qiita | `QIITA_ACCESS_TOKEN` | Qiita設定のトークン発行ページでトークン発行 |
| dev.to | `DEVTO_API_KEY` | dev.to設定のExtensionsページで API key 発行 |
| Zenn | — | GitHubリポジトリ連携のため手動 (Zenn CLIは別途) |

シークレット未設定の場合、そのプラットフォームはスキップされ `results.{platform}.error` に理由が記録される。
少なくとも1プラットフォームに投稿成功すると `blog_posts.status` が `'posted'` に更新される。

#### Step 5: コミット

```bash
git add docs/blog-drafts/YYYY-MM-DD.md docs/blog-drafts/YYYY-MM-DD-en.md
git commit -m "自動: ブログ下書き YYYY-MM-DD (日本語+英語)"
git push origin main
```

開発活動がない日 (コミット0件) はスキップ可。

#### Step 6: blog-publish.yml をディスパッチ (両言語を投稿)

```bash
# Qiita (日本語) + dev.to (英語) を同時投稿
gh workflow run blog-publish.yml \
  -f draft_path="docs/blog-drafts/YYYY-MM-DD.md" \
  -f draft_path_en="docs/blog-drafts/YYYY-MM-DD-en.md" \
  -f platforms="qiita,devto" \
  -f dry_run="false"
```

`draft_path_en` を省略した場合は Qiita のみ投稿 (dev.to スキップ)。

---

### AI大学 キラーコンテンツ化方針（毎セッション検討必須）

AI大学はユーザー数拡大のための**最重要差別化機能**。毎セッションで必ず以下の3Stepを実行する。

#### 目標 KPI

| KPI | 目標 | 測定方法 |
| --- | --- | --- |
| 週次アクティブ学習者率 | 登録ユーザーの 40% 以上 | ai_university_scores.studied_at |
| クイズ完了率 | 初回訪問の 60% 以上 | SharedPreferences → Supabase 移行後 |
| シェア転換率 | 学習完了の 10% 以上 | share_plus イベント計測 |
| ランキング参加率 | 学習者の 30% 以上 | ai_university_leaderboard ビュー |
| 連続学習日数 (ストリーク) | 平均 7 日以上 | ai_university_streaks テーブル |

#### 毎セッション 3Step（必須）

**Step A: ホームカード改善 (VSCode版)**

毎セッション必ず `lib/widgets/ai_university_home_card.dart` を見直す:

- 学習済みプロバイダー数・クイズ正解数・ストリーク日数を動的表示できるか？
- タップ時のCTA文言・ボタン色を改善できるか？
- 新規ユーザーと復帰ユーザーで表示を出し分けられるか？

**Step B: バイラル機能強化 (VSCode版)**

シェア・ランキング・バッジで口コミ拡散を加速する:

- **シェア文言 A/B テスト**: 「X 社を制覇」「クイズ全問正解」等バリエーションを試す
- **ランキングUI** (`ai_university_ranking_page.dart`): 週次TOP10・全体ランキング表示
- **バッジシステム** (`ai_university_badges` テーブル): 達成条件別バッジ発行・シェア誘導
- **SNSカード生成**: シェア時にOGP画像で「何社学習済み」を視覚化

**Step C: リテンション強化 (Windowsアプリ版 migration + VSCode版 EF)**

一度使ったユーザーが戻ってくる仕掛けを入れる:

- **学習ストリーク** (`ai_university_streaks`): 連続学習日数バッジ → 7日/30日/100日
- **学習リマインダー** (`notification-center` EF 連携): 3日未学習でプッシュ
- **コンテンツ鮮度表示**: 「X日前に更新」を AI大学ページに表示
- **パーソナライズ**: 学習済みプロバイダーを次回訪問時に先頭表示

#### 実装ロードマップ（優先度順）

| 優先度 | 機能 | 担当インスタンス | 状態 |
| --- | --- | --- | --- |
| ✅ | ランキングUI (`ai_university_ranking_page.dart`) | VSCode版 | ✅ 完了 (VSCode版#53) |
| ✅ | `ai-university-content` EF (GET/UPSERT) | Web版 | ✅ 完了 (Web版#28, PR#317) |
| ✅ | `ai_university_scores` スコア書込み (EF + Dart) | Web版+VSCode版 | ✅ 完了 (VSCode版#54 + Web版#33) |
| ✅ | `ai_university_streaks` EF + ストリークUI | Web版+VSCode版 | ✅ 完了 (Web版#29, VSCode版#54) |
| ✅ | `ai_university_badges` バッジ発行 EF | Web版 | ✅ 完了 (Web版#29/#33, PR#317) |
| ✅ | シェア文言 A/B テスト (3バリエーション) | VSCode版 | ✅ 完了 (VSCode版#54) |
| ✅ | ホームカード: ストリーク日数表示 | VSCode版 | ✅ 完了 (VSCode版#54) |
| ✅ | SNS シェア画像生成 (OGP カード) | VSCode版 | ✅ 完了 (VSCode版#56) |
| 🟢 中 | 学習リマインダー通知 (定期バッチ) | VSCode版 | EF action 実装済み / バッチ未設定 |
| 🔵 低 | 他ユーザー学習状況表示 | VSCode版 | 未実装 |

#### 既存実装（改善のベースライン）

| 機能 | 実装場所 | 改善ポイント |
| --- | --- | --- |
| ホーム最上部カード | `ai_university_home_card.dart` | ストリーク表示を追加 |
| シェア機能 | `gemini_university_v2_page.dart` `_shareProgress()` | バリエーション追加 |
| クイズ達成度 | SharedPreferences `ai_univ_answered_quizzes` | Supabase に移行してクロスデバイス対応 |
| プロバイダー無制限 | DB 駆動タブ (9社対応済み) | 毎セッションで新プロバイダー検討 |
| コンテンツ自動更新 | `ai-university-update.yml` (2時間毎) + Claude Schedule (4時間毎・NotebookLM) | ai-university-content EF 完成後にフル稼働 |
| DB スキーマ | `ai_university_scores` + `leaderboard` ビュー | EF とUI接続が未完了 |

---

### Task: ai-university-update (毎4時間実行)

> **アーキテクチャ**: GitHub Actions `ai-university-update.yml` が2時間毎に RSS ベースの軽量更新を行う。
> Claude Schedule (毎4時間) は NotebookLM Deep Research で**より深い情報**を収集してリッチなコンテンツを上書きする。
> 両者が同じ `ai_university_content.news` レコードを UPSERT するため、後から書いた方が最新版になる。

AI大学コンテンツを最新情報に自動更新する。**プロバイダー数は固定せず**、重要性が高い新興AIプロバイダーを毎回検討して随時追加する。

#### 現在の登録プロバイダー

```text
google, openai, anthropic, microsoft, meta, x, deepseek, mistral, perplexity, groq, cohere, core, amazon, stability, huggingface, nvidia, ibm, sakana, baidu, oracle, reka, aleph_alpha, together_ai, fireworks_ai, replicate, writer, ai21, voyage, elevenlabs, openrouter, ollama, runway, suno, ideogram, udio, luma, kling, pika, assemblyai, twelve_labs, qwen, moonshot, midjourney, hailuo, adobe_firefly, 01ai, coze, apple, databricks, samsung, zhipu, character_ai, inflection, allenai, naver, adept, cerebras, prover, lmsys, falcon_tii, black_forest_labs, liquid_ai, snowflake, cognition, scale_ai, poolside, harvey, manus, hedra, heygen, recraft, krea, tencent, bytedance, inception_labs, world_labs, runware, sambanova, lightricks, arcee_ai, minimax, moondream, rakuten_ai, pfn, siliconflow, novita_ai, deepinfra, nebius, fal_ai, fish_audio, atlas_cloud, mira_network, gmi_cloud, inworld, coreweave, lambda_labs, hyperbolic, anyscale, cerebrium, magic_ai
```

登録済みプロバイダーは `ai_university_content` テーブルの `provider` カラム個別値で確認できる。

#### Step 0: 新規プロバイダー候補を検討（毎回必須）

WebSearch で「AI provider new model release 2026」を検索し、以下の観点で新規追加候補を評価する:

| 評価基準 | 追加する | 見送る |
| --- | --- | --- |
| 技術的革新性 | 新アーキテクチャ・SOTA達成 | 既存モデルの軽微な更新のみ |
| 利用可能性 | API公開済み・広く利用可能 | クローズドβのみ |
| 話題性 | SNS/ニュースで大きく取り上げ | マイナーな言及のみ |

**候補プロバイダー例** (評価対象 — 追加済みでない場合):

```text
Mistral AI    (mistral)   — 欧州発オープンソース、Mistral Large/Small
Cohere        (cohere)    — エンタープライズRAG特化、Command R+
Perplexity AI (perplexity)— AI検索エンジン、独自LLM
Amazon        (amazon)    — Amazon Nova/Bedrock、AWS AI統合
Apple         (apple)     — Apple Intelligence、オンデバイスAI
Baidu         (baidu)     — ERNIE Bot、中国最大AI
Samsung       (samsung)   — Gauss、オンデバイスAI
```

**新規追加が決まったら**:

1. `supabase/migrations/YYYYMMDDXXXXXX_seed_{provider}_ai_university.sql` を作成し overview / models / api の3カテゴリで初期コンテンツを seed
2. `lib/pages/gemini_university_v2_page.dart` の `_providerMeta` マップに表示設定を追加（任意: 未登録でもタブは自動生成されるが色・絵文字がデフォルトになる）
3. `_fallback` マップ（同ファイル）にフォールバック markdown を追加
4. `_quizzes` マップ（同ファイル）にクイズを追加（任意）
5. `ai-university-update.yml` の検索クエリリストにプロバイダーを追加
6. COMPRESSED_PROMPT_V3.md の「現在の登録プロバイダー」リストを更新

#### Step 1: NotebookLM Deep Research で最新AIニュースを収集（必須）

GitHub Actions の RSS 更新より深い情報を取得するため、必ず NotebookLM を使う:

```bash
# 全プロバイダーを一括でリサーチ (専用ノートブック or Master Brain)
notebooklm use jibun-master-brain
notebooklm source add-research "Google Gemini OpenAI GPT Anthropic Claude Microsoft Copilot Meta LLaMA xAI Grok DeepSeek Mistral Perplexity latest AI news releases API changes 2026"
notebooklm research wait
notebooklm ask "各AIプロバイダー (Google/OpenAI/Anthropic/Microsoft/Meta/xAI/DeepSeek/Mistral/Perplexity) の最新ニュース・モデルリリース・API変更をプロバイダー別に日本語でまとめてください"
```

認証切れの場合: `notebooklm login` で再認証 (30秒)。
NotebookLM が利用不可の場合は WebSearch にフォールバック:

```text
WebSearch フォールバック (各プロバイダーごと):
- Google:    "Google Gemini AI latest news models 2026"
- OpenAI:    "OpenAI GPT o1 o3 latest news 2026"
- Anthropic: "Anthropic Claude latest news models 2026"
- Microsoft: "Microsoft Copilot Azure OpenAI latest 2026"
- Meta:      "Meta AI LLaMA latest news 2026"
- X/xAI:    "xAI Grok latest news models 2026"
- DeepSeek: "DeepSeek AI latest news models 2026"
- Mistral:  "Mistral AI latest news models 2026"
- Perplexity: "Perplexity AI Sonar latest news 2026"
```

各プロバイダーの公式ブログ・リリースノートも参照する:

```text
https://blog.google/technology/ai/
https://openai.com/news/
https://www.anthropic.com/news
https://blogs.microsoft.com/ai/
https://ai.meta.com/blog/
https://x.ai/blog
https://api-docs.deepseek.com/news/
```

#### Step 2: `ai_university_content` テーブルを UPSERT で更新

`ai-university-content` EF (または Supabase REST API) で各プロバイダーの `news` カテゴリレコードを更新する:

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-university-content
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{
  "action": "upsert_news",
  "provider": "google",
  "title": "Google AI 最新ニュース (YYYY-MM-DD)",
  "content": "## 今週の最新情報\n\n[取得した内容をMarkdown形式で]",
  "published_at": "YYYY-MM-DD"
}
```

または Supabase REST API を直接使用:

```bash
curl -X POST \
  "https://smmkxxavexumewbfaqpy.supabase.co/rest/v1/ai_university_content" \
  -H "apikey: <SUPABASE_SERVICE_KEY>" \
  -H "Authorization: Bearer <SUPABASE_SERVICE_KEY>" \
  -H "Content-Type: application/json" \
  -H "Prefer: resolution=merge-duplicates" \
  -d '{"provider":"google","category":"news","title":"...","content":"...","published_at":"YYYY-MM-DD"}'
```

#### Step 3: 更新サマリーを記録してコミット

変更内容を `docs/daily-reports/YYYY-MM-DD.md` の末尾に追記:

```markdown
## AI大学コンテンツ更新 (ai-university-update)
- Google: Gemini 2.x 最新リリース情報を更新
- OpenAI: o3 mini 料金改定情報を追加
- DeepSeek: V3 新バージョン情報を追加
- 新規追加: [プロバイダー名] — [追加理由]
- ...（各プロバイダーの更新内容）
```

```bash
git add docs/daily-reports/ supabase/migrations/ .github/workflows/
git commit -m "自動: AI大学コンテンツ更新 YYYY-MM-DD"
git push origin main
```


---

### Task: feature-review (毎時 0 分に実行 / 13 機能 round-robin)

**起源**: Win版#132 part 77 → part 78 (= 頻度週次 → 毎時に変更) / 2026-04-29 / Handoff Bundle 第 1 適用例
**Bundle**: `docs/handoff-bundles/20260429_feature_review_scheduled_task/` (= 完成後 `done/` 移動)
**親軸**: COLLAB_AI #5 Verifier-Generator / OPS-28 改善トリガー / VIBE_CODING #4 Black-Box I/O Verification

#### 概要

13 機能 (= 9 page + 4 Edge Function) を **毎時 0 分に 1 機能ずつ round-robin** で AI レビューし、**修正すべき問題を GitHub Issue 自動起票** する. 24 時間で 1.8 周 = high priority 機能は 1 日 2 回見られる.

#### Step 1: 対象機能選択 (= rotation)

`scripts/feature_review_config.json` から `rotation.feature_order` (= 13 機能優先度順リスト) を読込.

`UTC_HOUR_NOW % 13` でインデックス計算 → 1 機能を選択 (= 毎時 1 機能のみ).

例: UTC 0 時 → home / UTC 1 時 → ai_university / ... / UTC 12 時 → admin_analytics / UTC 13 時 → home (= 2 周目).

`workflow_dispatch` で `force_full_scan=true` の場合のみ全機能巡回 (= 緊急時 audit).

#### Step 2: シグナル収集 (機能ごと)

- **Page (Flutter)**:
  - Playwright で本番 URL screenshot (= 1280×720 / 将来 2576px)
  - console messages 取得 (= error / warning)
  - DOM accessibility tree 取得 (= a11y チェック用)
- **Edge Function (Deno)**:
  - source の TODO/FIXME 検索
  - 直近 git log (= 最近の変更履歴)
  - deno lint 結果 (= cache or 即時実行)

#### Step 3: Claude API レビュー

Haiku 4.5 + effort=medium で signals を bundle → JSON 形式 findings 出力 (= max 3 件 / feature).

```json
{
  "findings": [
    {
      "feature_slug": "horse_racing",
      "category": "ui_bug",
      "severity": "medium",
      "summary": "オッズ列のテキストが幅 320px で折り返し",
      "review_text": "Playwright screenshot で...",
      "recommendation": "FittedBox or AutoSizeText の適用"
    }
  ]
}
```

#### Step 4: de-dupe + Issue 起票

- title hash 計算 (= `feature_slug | category | summary[:80]` の SHA-256 先頭 8 文字)
- 既存 open issue が同 hash なら skip
- 新 finding → `gh issue create` で起票:
  - Title: `[review:<hash>] /<path> <category> <summary>`
  - Labels: `auto-review`, `severity:<level>`, `feature:<slug>`, `category:<cat>`
  - Body: signals + Claude review + recommendation

#### Step 5: Slack 通知 + 記録

- `SLACK_WEBHOOK_URL` 経由で集計通知 (= `🔍 feature-review run complete: N new / M skipped / E errors`)
- `docs/feature-review-logs/<YYYY-MM-DD>.md` に詳細ログ保存

#### 制約

- max 3 issues per run (= 1 機能のみだが余裕枠 / ノイズ抑制)
- max 1 issue per feature (= 同一 feature で連発防止)
- max 3 findings per feature (= Claude が出す候補は 3 件まで)
- Playwright timeout 30s / Claude API max retry 3 / GitHub API quota 監視
- de-dupe: 既存 open issue + 7 日以内 closed を skip

#### 成功条件

- 初日 (= 24 cron run): 13 機能 × 1.8 周 = 0-13 件 issue 起票 (= 真の問題発見)
- 翌日: de-dupe 効いて 0-3 件 (= 既存問題は再起票せず)
- 1 週後: 既存 issue 半数 closed (= 開発反映 cycle 健全)
- 緊急時: `workflow_dispatch` + `force_full_scan=true` で 13 機能即時 audit

---

### Task: ai-tool-harness-review (毎日 06:15 JST / セッション開始時)

**起源**: NotebookLM `bc58b50b-5fc4-4840-9a62-b397d6d3b65a`
「Codex vs Claude Code: The Ultimate AI Development Synergy」適用 / 2026-04-30
**Workflow**: `.github/workflows/ai-tool-watch.yml`
**Script**: `scripts/ai_tool_watch.py`
**Report**: `docs/ai-tool-watch/latest-report.md`

#### 目的

Claude Code / Codex の公式変更と NotebookLM の Harness Engineering 方針を毎日・毎セッションで照合し、
12 インスタンスの担当分担、WBS 優先度、スケジュールタスク候補、GitHub Actions 品質ゲートへ反映する。

#### Step 1: 公式情報を取得

`scripts/ai_tool_watch.py` が以下の一次情報を取得する。

- Claude Code changelog: `https://code.claude.com/docs/en/changelog`
- Claude Code hooks: `https://code.claude.com/docs/en/hooks`
- Claude Code GitHub Actions: `https://code.claude.com/docs/en/github-actions`
- Codex changelog: `https://developers.openai.com/codex/changelog`
- Codex use cases: `https://developers.openai.com/codex/use-cases/`
- Codex overview: `https://openai.com/codex/`

#### Step 2: NotebookLM Harness へ写像

検出したキーワードを次の担当へ振り分ける。

| 検出カテゴリ | 担当 | WBS 反映先 |
| --- | --- | --- |
| hooks / SessionStart / PostToolUse / Stop | Claude Code | 品質ゲート設計、hook runbook、セッション開始ルール |
| model / in-app browser / computer use / worktree | Codex#1 | UI検証、横断修正、クリーン worktree PR |
| CI / GitHub Actions / deploy / sync | Codex#2 | red check 修復、deploy unblock、WBS/Issue/Notion同期 |
| MCP / Slack / Notion / connector | Claude Code + Codex#2 | 連携基盤、通知、外部メモリ同期 |
| cost / quota / sandbox / permission | Claude Code | 自動化範囲、deny-by-default、予算・権限境界 |

#### Step 3: 出力と反映

- `docs/ai-tool-watch/latest-report.md` を更新する。
- high-priority change があれば `#1422` へ comment する。
- 新しい hook / workflow / automation 候補がある場合は GitHub Issue を起票する。
- WBS 上位 20 件に手動反復タスクがある場合、`feature-review` または新規 Schedule タスクへ昇格する。
- 既存 PR が clean / checks pass なら merge queue 候補に入れ、conflict PR は Codex#2 に回す。

#### セッション開始の手動確認

ローカルでは次を実行する。

```powershell
python scripts/codex_session_check.py
python scripts/ai_tool_watch.py --print-only
```

出力に `changed/new official sources` がある場合は、必ず「WBS route / GitHub issue / hook / workflow / PR」の
いずれかに落とし、NotebookLM のメモだけで完了にしない。

`codex_session_check.py` に dirty worktree、upstream gone、base branch 直編集、origin/main 未取得などの警告が
出た場合は、実装前に新しい worktree / branch へ移るか、Codex#2 に sync / CI 側の修復として回す。


<<<<<<< Updated upstream
## NotebookLM 9b8885ef Schedule Resilience Guard (#1783)

NotebookLM `9b8885ef` ("Automating SaaS Operations with Claude Code Schedule") is applied as a
cross-cutting guard instead of duplicating retry code inside every scheduled workflow.

**Workflow**: `.github/workflows/schedule-resilience-watch.yml`
**Script**: `scripts/schedule_resilience_watch.py`
**Scope**: `daily-report.yml`, `cs-check.yml`, `competitor-monitoring.yml`, `infra-health-check.yml`

Guard contract:

1. **Retry**: when the latest scheduled run failed and `run_attempt < 2`, rerun failed jobs once through the GitHub Actions API.
2. **Fallback**: when retry is exhausted, the run conclusion is unexpected, or no recent scheduled run exists, keep the guard itself green and preserve a JSON artifact for triage.
3. **Alerting**: open or update a `workflow-failure` issue titled `[Schedule監視] <task> ...` with run URL, status, attempt, and the Codex #1 ownership note.
4. **Freshness**: hourly schedules (`cs-check`, `infra-health-check`) must have a scheduled run within 3h; daily schedules (`daily-report`, `competitor-monitoring`) within 30h.

2-instance routing:

- Claude Code #1 owns automation pattern design and doc triage.
- Codex #1 owns the old PS#1 workflow-health implementation lane and GitHub Actions CI integration.

Manual dry run:

```bash
python scripts/schedule_resilience_watch.py --repo kanta13jp1/my_web_app --dry-run --output tmp/schedule-resilience/report.json
```
=======
---

## SaaS Operations Automation Patterns (= NotebookLM 9b8885ef distill / part 181)

> **Source**: NotebookLM ノートブック `9b8885ef` "Automating SaaS Operations with Claude Code Schedule"
> **Issue**: #1783 | **Win Claude** (本 spec) → **Codex** (gap 実装 hand-off)
> **Created**: 2026-05-10 (part 181)

### A.1 背景

Claude Code Schedule (= 定期 cron AI agent) で SaaS 操作 (= GHA / Supabase EF / WBS / Slack / Notion) を完全自動化するための 5 pattern を 9b8885ef から抽出 + 既存 15 workflow の gap 監査.

### A.2 5 SaaS automation patterns

#### Pattern 1 — Idempotency Key (= 再実行安全性)

各 schedule task は `idempotency_key = sha256(<task>:<window_id>)` を artifact / DB / Issue body に記録. 同 key 検出時は no-op.

```yaml
# 例 (.github/workflows/<task>.yml)
- run: |
    KEY=$(echo "${{ github.workflow }}:$(date -u +%Y-%m-%dT%H)" | sha256sum | cut -c1-12)
    if gh issue list --search "[idem:$KEY]" --state all | grep -q .; then exit 0; fi
    # ... 実処理 ...
    gh issue comment <n> -b "[idem:$KEY] done"
```

#### Pattern 2 — Multi-AI Fallback Chain (= graceful degradation)

primary (Claude Code) → secondary (Codex CLI) → tertiary (Gemini Code Assist) を順に試行. 各失敗は trace_id 付き log → 最終失敗時のみ Issue 起票 + Slack 通知.

優先順は `docs/AI_FALLBACK_RUNBOOK.md` 既存定義 + 各 task で env `AI_FALLBACK_CHAIN=claude,codex,gemini` で override 可.

#### Pattern 3 — Self-Healing Loop (= 失敗検知 → 自動修復 → escalation)

3 layer:

1. **Detect**: artifact size 0 / exit code != 0 / KPI 閾値超 → workflow level retry (max 3, exponential backoff 30s/2m/10m)
2. **Recover**: dispatch 別 workflow `<task>-recovery.yml` (= rerun + cleanup + Issue 起票)
3. **Escalate**: 3 day 連続失敗 → label `automation-degraded` + WBS task add (= Codex 手動修復)

#### Pattern 4 — Observability Triple (= artifact + metrics + alerts)

各 task で:

- **artifact**: `tmp/<task>-<run_id>.json` 必須 (= 入出力 + KPI 数値 + trace_id)
- **metrics**: `docs/metrics/<task>.csv` に 1 row append (timestamp / status / elapsed_sec / cost_usd)
- **alerts**: `docs/metrics/<task>.csv` 7-day median elapsed > p95 historical → warning Issue (= label `slo-breach`)

#### Pattern 5 — Time-Window Throttling (= rate limit + circuit breaker)

外部 API (X / Notion / Slack / Anthropic / OpenAI) call 前に `task_budget` 共通 EF (= 既存 `_shared/task_budget.ts`) で:

- per-task daily quota (= `<task>:<YYYY-MM-DD>` Redis-like key)
- 429 検出時 cooldown (= `_shared/AiQuotaGuard` pattern / 60 sec)
- circuit open (= 5 min 内 3 連続失敗) で 30 min 全停止 → Slack alert

### A.3 既存 15 workflow gap 監査

| workflow | P1 idem | P2 fallback | P3 self-heal | P4 obs triple | P5 throttle |
|---|---|---|---|---|---|
| feature-review | ✅ (hash) | ❌ | ⚠️ retry のみ | ✅ artifact / ❌ metrics / ✅ Slack | ⚠️ max 3/run |
| daily-report | ❌ | ❌ | ✅ #2154 で fix | ⚠️ artifact only | ❌ |
| cs-check | ❌ | ❌ | ❌ | ✅ artifact | ❌ |
| competitor-monitoring | ❌ | ⚠️ retry のみ | ❌ | ⚠️ artifact only | ❌ |
| cron-batch | ❌ | ❌ | ❌ | ❌ | ❌ |
| codex-session-safety-cron | ❌ | ❌ | ❌ | ❌ | ❌ |
| daily-report-freshness-monitor | ✅ date key | ❌ | ❌ | ❌ | ❌ |
| dev-cache-cleanup-cron | ✅ idem | ❌ | ❌ | ❌ | ❌ |
| docs-rotate-cron | ✅ monthly | ❌ | ❌ | ❌ | ❌ |
| health-monitor | ❌ | ❌ | ❌ | ⚠️ artifact only | ❌ |
| inject-rules-drift-cron | ❌ | ❌ | ❌ | ⚠️ artifact only | ❌ |
| quota-monitor | ❌ | n/a | ❌ | ⚠️ Slack only | n/a (= 自身が monitor) |
| self-devin-schedule | ❌ | ❌ | ❌ | ❌ | ❌ |
| wbs-auto-reschedule | ❌ | ❌ | ❌ | ❌ | ❌ |
| worktree-cleanup-cron | ✅ weekly | ❌ | ❌ | ❌ | ❌ |

集計: P1=6/15 ✅ / P2=0/15 / P3=1/15 ✅ / P4=8/15 ⚠️ / P5=0/15 → **P2/P3/P5 が完全 gap**.

### A.4 [INSTANCE-ROLES] 振分

| 担当 | スコープ | 期限 |
|---|---|---|
| **Win Claude (= 本 spec)** | 5 pattern 抽出 + 15 workflow gap 監査 + acceptance criteria | part 181 完了 |
| **Win Codex (= hand-off)** | gap 修正 (P2 multi-AI fallback chain helper / P3 self-heal recovery workflow / P5 task_budget integration) | 2026-05-24 |

Codex 振分 5 質問 score:

| Q | A |
|---|---|
| 1. 設計 / アーキ判断要? | NO (= 5 pattern 確定) |
| 2. 横断 docs / memory 編集要? | NO |
| 3. UI design 要? | NO |
| 4. triage / hand-off 判断要? | NO |
| 5. mobile UAT / 動画要? | NO |

= 0/5 → 完全 Codex 案件.

### A.5 Codex 実装スコープ

#### A.5.1 P2 multi-AI fallback chain helper (新規)

```bash
# scripts/ai_fallback_invoke.sh
# 使用: ai_fallback_invoke.sh "claude" "<prompt>" "<artifact_path>"
# claude 失敗 → codex 失敗 → gemini で順に試行 / trace_id ログ
```

各 schedule workflow から `run: ai_fallback_invoke.sh ...` で呼び出し可能化.

#### A.5.2 P3 self-heal recovery workflow (新規)

`.github/workflows/<task>-recovery.yml` template (3 件 priority):
1. `daily-report-recovery.yml` (= 既存 freshness-monitor 拡張)
2. `cs-check-recovery.yml`
3. `competitor-monitoring-recovery.yml`

template structure:
```yaml
on:
  workflow_run:
    workflows: ["<task>"]
    types: [completed]
jobs:
  recover:
    if: ${{ github.event.workflow_run.conclusion == 'failure' }}
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/recover_<task>.sh ${{ github.event.workflow_run.id }}
      - uses: actions/upload-artifact@v4
```

#### A.5.3 P5 task_budget integration

既存 `supabase/functions/_shared/task_budget.ts` を schedule cron からも呼び出せる helper:

```bash
# scripts/budget_check.sh <task> <provider> <est_tokens>
# exit 0 = OK / 1 = budget exceeded (= workflow short-circuit)
```

各 AI 呼び出し workflow 先頭で `run: scripts/budget_check.sh ${{ github.workflow }} anthropic 5000 || exit 0`.

### A.6 受け入れ条件

- [ ] `scripts/ai_fallback_invoke.sh` 実装 + 1 workflow で実証 (= daily-report 推奨)
- [ ] `daily-report-recovery.yml` / `cs-check-recovery.yml` / `competitor-monitoring-recovery.yml` ship
- [ ] `scripts/budget_check.sh` 実装 + 全 AI workflow に integration
- [ ] gap 監査表更新 (P2 0→3+ / P3 1→4+ / P5 0→5+) を 1 week 後 spec doc に追記
- [ ] PR コメントに 1-week 観測の retry 数 + recovery success 率 + budget 抑止数

### A.7 KPI / 監視

| metric | 計測 | 目標 |
|---|---|---|
| `automation_fail_rate_7d` | docs/metrics/all_workflows.csv | ≤ 5% |
| `recovery_success_rate_7d` | recovery.yml artifact | ≥ 80% |
| `budget_block_count_7d` | budget_check.sh log | < 10 (= 過剰 block 防止) |
| `mttr_minutes_p95` | recovery start - failure | ≤ 60 min |

### A.8 PHILOSOPHY-22 alignment

| 原則 | 対応 |
|---|---|
| #6 時間最適化 | ✅ 失敗 → 手動 fix → user 介在 0 化 |
| #7 資産負債 | ✅ self-heal = 信頼性資産 / 失敗放置 = 負債 |
| #8 KPI 自分比較 | ✅ 7-day median 監視 |
| #9 IPO | ✅ 持続的 SaaS 自動化 = 規模化基盤 |
| #1 CEO 感 | ✅ escalation 時のみ user 通知 |
| #3 mentor | ✅ 失敗 silent / Issue で穏やか報告 |
| #5 商品=価値 | ✅ 安定動作 = ユーザー信頼 |

= 7/9 ✅ ([PHILOSOPHY-22] gate 通過).

>>>>>>> Stashed changes
