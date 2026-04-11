# 自分株式会社 — Claude Code 設定

## プロジェクト概要

Flutter Web + Supabase のAI統合ライフマネジメントアプリ。
Notion・Evernote・MoneyForward・Slack・X・Amazon など21競合の機能を1つに統合。
本番URL: <https://my-web-app-b67f4.web.app/>

### 技術スタック

- **フロントエンド**: Flutter Web (Dart)
- **バックエンド**: Supabase (PostgreSQL + Edge Functions / Deno)
- **ホスティング**: Firebase Hosting
- **CI/CD**: GitHub Actions (push to main → 自動デプロイ)
- **メール**: Resend API

### 競合21社

notion, evernote, moneyforward, slack, chatwork, x, animaworks,
claude-code, codex, netkeiba, openclaw, claude-cowork, jobcan, amazon,
google, microsoft, discord, line, facebook, liven, github

---

## デザインシステム参照 (UI生成時に必ず参照)

UIコンポーネントを新規作成・修正する際は、以下のファイルを参照してデザイントークンを適用すること:

- **自分株式会社デザイントークン**: `docs/DESIGN.md`
- **日本語UIリファレンス (awesome-design-md-jp)**:
  - `docs/design-systems/note/DESIGN.md` — note.com (teal #5ac8b8, line-height 2.0, 620px幅)
  - `docs/design-systems/freee/DESIGN.md` — freee (blue #2864f0, 4pxグリッド, システムフォント)
  - `docs/design-systems/smarthr/DESIGN.md` — SmartHR (blue #0077c7, Yu Gothicマッピング, 8pxグリッド)
  - `docs/design-systems/apple/DESIGN.md` — Apple JP (SF Pro JP, ピルボタン, #1d1d1f)
  - `docs/design-systems/wired/DESIGN.md` — WIRED.jp (黒×黄, body全体にpalt, 角張りデザイン)
  - `docs/design-systems/template/DESIGN.md` — 新サービス追加用テンプレート

**重要ルール**:

- 日本語本文の `letter-spacing` は原則 0（見出しのみ使用可）
- 本文の `line-height` は最低 1.5（推奨 1.7〜2.0）
- Yu Gothic を使う場合は `@font-face` で Medium→400 マッピングを使う
- `font-feature-settings: "palt" 1` は見出し・ナビのみ適用（本文には非適用が原則）

---

## 開発ルール (常に適用)

1. **`flutter analyze` を常に0エラー維持** — コード変更後は必ずチェック
2. **`deno lint` を常に0エラー維持** — Edge Function 変更後は必ずチェック
3. **`docs/GROWTH_STRATEGY_ROADMAP.md` を毎回更新** — 変更内容をセッション記録に追記
4. **ダミーデータ禁止** — 必ずSupabaseのリアルデータを使用
5. **Edge Functionファースト** — 複雑なロジックはバックエンドに移動
6. **シンプルさ優先** — 明示的に依頼されていない機能は追加しない
7. **毎セッション: `docs/` 戦略ドキュメント全件分析・開発計画反映** — 以下の常設ドキュメントを読み、(a) 矛盾・鮮度切れを修正、(b) 未着手タスク・ブロッカーを `COMPRESSED_PROMPT_V3.md` の「実装待ち」セクションに追記する。
   - 対象: `docs/CICD_SETUP_GUIDE.md`, `docs/CONTRIBUTING.md`, `docs/MULTI_INSTANCE_COORDINATION.md`, `docs/README.md`, `docs/DESIGN_TOOLING_SETUP.md`, `docs/technical/*.md`, `docs/roadmaps/*.md`, `docs/user-docs/*.md`
   - 除外 (自動生成・アーカイブ): `docs/daily-reports/`, `docs/cs-notes/`, `docs/blog-drafts/`, `docs/blog/`, `docs/competitor-reports/`, `docs/incident-reports/`, `docs/security-audit/`, `docs/archive/`, `docs/email-templates/`, `docs/weekly-drafts/`

---

## Multi-AI ワークフロー（毎回必ず実行）

**設計思想**: 「どの処理をどの AI に振るか」を設計することで、月 $20 プランで $200 相当の作業を実現する。
Claude のトークンは「判断・編集・統合」のみに使い、重い分析は Google (NotebookLM/Gemini) に無料で投げる。

### セッション開始: Master Brain 参照

セッション開始時に必ず以下を確認する:

```text
C:\Users\kanta\.claude\projects\C--Users-kanta-GitHub-my-web-app\memory\MEMORY.md
```

前回の成功パターン・禁止事項・新規発見を読んで、セッションの出発点とする。
記憶が消える弱点を「永続メモリ + NotebookLM Master Brain」で補う。

### 重い分析: `/deep-research` で NotebookLM に委譲（必須）

以下のいずれかに該当する場合は **必ず** `python notebooklm_research.py` を呼ぶ:

| 条件 | Claude 消費 | NotebookLM 委譲後 |
| --- | --- | --- |
| 3ファイル以上を同時に読む | ~150K tokens | ~5K tokens |
| URLを分析する | ~60K tokens | ~2K tokens |
| 競合21社のリサーチ | ~80K tokens | ~3K tokens |
| ドキュメント全体を俯瞰する | ~100K tokens | ~4K tokens |

**コマンド**:

```bash
# セットアップ確認（初回のみ）
PYTHONUTF8=1 python notebooklm_research.py --setup

# トピック検索
PYTHONUTF8=1 python notebooklm_research.py "競合21社の最新動向"

# ファイル分析（3ファイル以上は必須）
PYTHONUTF8=1 python notebooklm_research.py --files lib/pages/landing_page.dart docs/DESIGN.md --query "UIと設計の整合性"

# URL調査
PYTHONUTF8=1 python notebooklm_research.py --url "https://..." --query "要約して"
```

スクリプトがない or 認証未完了の場合は以下を案内して処理を止める:

```text
notebooklm login が必要です:
  pip install "notebooklm-py[browser]"
  playwright install chromium
  notebooklm login
```

### セッション終了: `/wrap-up` で学習を永続保存（必須）

作業完了後、必ず `/wrap-up` を実行する:

1. ローカル memory/ に保存:
   - 成功パターン → `memory/feedback_success_YYYYMMDD.md`
   - 失敗・禁止事項 → `memory/feedback_correction_YYYYMMDD.md`
   - 新規発見 → `memory/project_YYYYMMDD.md`
2. NotebookLM Master Brain に蓄積（認証済みの場合のみ）:

   ```bash
   PYTHONUTF8=1 python notebooklm_research.py --notebook "jibun-master-brain" "[セッション要約300字]"
   ```

3. 未完了タスク → `MEMORY.md` 末尾にコメント記録
4. **次回タスク候補を必ず提案** — **特に未完了タスクが 0 件の場合は必須**。セッション終了時に次回実施タスク候補 3〜5件を優先度付き表で提示する（詳細フォーマットは `.claude/commands/wrap-up.md` の Step 6 参照）

**これを怠るとセッション間の記憶が消え、同じ失敗を繰り返す。**

### NotebookLM セットアップ状態

- **インストール**: `pip install "notebooklm-py[browser]"` + `playwright install chromium`
- **認証**: `notebooklm login` (ブラウザで Google ログイン、一度だけ必要)
- **確認**: `PYTHONUTF8=1 python notebooklm_research.py --setup`
- **注意**: Windows では必ず `PYTHONUTF8=1` を付けて実行すること (CP932 エンコードエラー回避)

---

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
```

**ケース A: ファイルが存在し `<!-- generated-by: github-actions -->` を含む場合**

Read ツールでファイルを読み込み、概要セクション（ユーザー数・リクエスト数等）を
そのまま利用する。Step 3・Step 4 は Actions 実施済みとしてスキップ可。

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
   a. コードを修正
   b. `flutter analyze` を実行し 0 エラーを確認（Dart の場合）
   c. `git add -p && git commit -m "fix: <バグ内容>" && git push origin main` でコミット
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
2. 各PRの差分を取得し、セキュリティ・パフォーマンス・ロジックバグの観点でレビュー
3. 指摘があれば `gh pr review` でコメント投稿
4. 問題なければ approve
5. **CI失敗PR対応**: `ci-auto-fix.yml` が `dart fix --apply` + `deno fmt` を自動適用済みの場合は
   その結果コメントを確認し、残存エラーがあれば追加コメントで手動修正を促す。
   `ci-auto-fix.yml` 未実行の場合は `gh run list --branch <branch>` で CI ログを確認して
   修正可能なエラー (deprecated API / import typo 等) があればコードを直接修正してコミット。

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

#### Step 2: ブログ下書きを生成・保存

ファイルパス: `docs/blog-drafts/YYYY-MM-DD.md`

```markdown
# ブログ下書き YYYY-MM-DD

## タイトル案
{実装内容を技術的に面白く表現したタイトル (3案)}

## 投稿先候補
- [ ] Zenn
- [ ] Qiita
- [ ] note
- [ ] はてなブログ
- [ ] X Article

## 本文下書き (1500〜3000字)
{以下の構成で書く}

### はじめに
{なぜこの機能を作ったか、どんな課題を解決するか}

### 実装方法
{Flutter/Supabase での具体的な実装手順、コードスニペット付き}

### 詰まったポイント
{実際にハマった部分と解決策}

### まとめ
{今後の展望、リポジトリ/サービスへのリンク}

---
URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic
```

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
git add docs/blog-drafts/
git commit -m "自動: ブログ下書き YYYY-MM-DD"
git push origin main
```

開発活動がない日 (コミット0件) はスキップ可。

---

## ディレクトリ構成 (主要)

```text
lib/
  main.dart              # ルーティング
  pages/
    landing_page.dart    # LP (比較リンク、FAB CTA)
    comparison_page.dart # 競合比較ページ (21社)
    user_manual_page.dart
    admin_analytics_page.dart
supabase/
  functions/             # Deno Edge Functions
  migrations/            # SQL migration files
docs/
  GROWTH_STRATEGY_ROADMAP.md  # 開発記録 (毎回更新)
  daily-reports/         # Claude Schedule が生成する日次レポート
  cs-notes/              # Claude Schedule が生成する CS チェックメモ
  weekly-drafts/         # Claude Schedule が生成する週次SNSドラフト
  competitor-reports/    # Claude Schedule が生成する競合モニタリングレポート
  incident-reports/      # Claude Schedule が生成するインシデントレポート
  security-audit/        # Claude Schedule が生成する脆弱性チェックレポート
web/
  index.html             # SEO meta tags
  sitemap.xml            # 22 URLs
```

## Supabase Edge Function 一覧

| Function | 用途 |
| --- | --- |
| `schedule-daily-digest` | Claude Schedule 用の日次メトリクス API |
| `get-support-tickets` | Claude Schedule 用: 未返信チケット+FAQ一覧 |
| `reply-support-request` | Claude Schedule 用: チケット返信・エスカレーション |
| `get-home-dashboard` | ホーム画面統合データ |
| `notify-feature-request` | 機能リクエスト更新通知メール |
| `growth-weekly-digest` | 週次グロース指標 |
| `development-achievements` | 開発実績一覧 |
| `get-admin-users` | 管理者用ユーザー一覧 |
| `daily-judgment` | AI デイリー判定 |
| `ai-assistant` | AI アシスタント |
| `post-x-update` | X (Twitter) 自動投稿 (@kanta13jp1) |
| `get-growth-roadmap-progress` | 進捗バーデータ (21競合+短中長期) |
| `get-competitor-features` | 競合21社の機能比較データ |
| `health-check` | インフラヘルスチェック |
| `check-competitor-updates` | 競合21社のWebサイト可用性チェック |

---

## 開発実績の記録方法

新しい機能を実装したら必ず `supabase/migrations/` に seed ファイルを作成:

```sql
-- Session XX: 実装内容の概要
INSERT INTO development_achievements (title, description, completed_at)
VALUES ('タイトル', '詳細説明', 'YYYY-MM-DD')
ON CONFLICT DO NOTHING;
```

## マイグレーションファイルの命名規則

`YYYYMMDDXXXXXX_descriptive_name.sql`
例: `20260326000010_seed_achievements_session20.sql`
