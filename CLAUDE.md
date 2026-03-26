# 自分株式会社 — Claude Code 設定

## プロジェクト概要

Flutter Web + Supabase のAI統合ライフマネジメントアプリ。
Notion・Evernote・MoneyForward・Slack・X・Amazon など14競合の機能を1つに統合。
本番URL: <https://my-web-app-b67f4.web.app/>

### 技術スタック

- **フロントエンド**: Flutter Web (Dart)
- **バックエンド**: Supabase (PostgreSQL + Edge Functions / Deno)
- **ホスティング**: Firebase Hosting
- **CI/CD**: GitHub Actions (push to main → 自動デプロイ)
- **メール**: Resend API

### 競合14社

notion, evernote, moneyforward, slack, chatwork, x, animaworks,
claude-code, codex, netkeiba, openclaw, claude-cowork, jobcan, amazon

---

## 開発ルール (常に適用)

1. **`flutter analyze` を常に0エラー維持** — コード変更後は必ずチェック
2. **`deno lint` を常に0エラー維持** — Edge Function 変更後は必ずチェック
3. **`docs/GROWTH_STRATEGY_ROADMAP.md` を毎回更新** — 変更内容をセッション記録に追記
4. **ダミーデータ禁止** — 必ずSupabaseのリアルデータを使用
5. **Edge Functionファースト** — 複雑なロジックはバックエンドに移動
6. **シンプルさ優先** — 明示的に依頼されていない機能は追加しない

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

以下のステップを順番に実行してください:

#### Step 1: 日次メトリクスを取得

WebFetch で以下を呼び出す:

```http
GET https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/schedule-daily-digest
Authorization: Bearer <SUPABASE_SERVICE_KEY>
```

レスポンスの `digest` オブジェクトを取得する。

#### Step 2: 日次レポートを生成・保存

取得した `digest` を元に、以下のフォーマットで日次レポートを作成する。
ファイルパス: `docs/daily-reports/YYYY-MM-DD.md`

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

## 次のアクション提案
AIとして、上記データを踏まえた優先対応事項を3点提案する。
特に投票数の多い機能リクエストや、ユーザー成長に繋がるアクションを優先。
```

#### Step 3: X (Twitter) に投稿

直近24時間の `git log --oneline` を確認し、ユーザーに価値のある変更があれば X に投稿する。

投稿文のルール:

- 140字以内
- カジュアルで前向きなトーン
- ハッシュタグ: `#buildinpublic #FlutterWeb #Supabase` から2〜3個
- ユーザー数の変化や新機能を含める
- 投稿先アカウント: **@kanta13jp1**

```http
POST https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/post-x-update
Authorization: Bearer <SUPABASE_SERVICE_KEY>
Content-Type: application/json
{ "text": "<生成した投稿文>" }
```

変更がない日や投稿不要と判断した場合はスキップ可。

#### Step 4: 競合モニタリング

以下の競合サイトを WebFetch でチェックし、前回レポートと差分があれば記録する:

- [Notion](https://www.notion.so/)
- [Evernote](https://evernote.com/)
- [Slack](https://slack.com/intl/ja-jp/)

確認観点:

- 新機能アナウンス
- 価格変更
- UIの大きな変更

変化を検知した場合は日次レポートの末尾に `## 競合動向` セクションを追加して記録する。
変化がなければスキップ可。

#### Step 5: コミット

作成したファイルをコミットする:

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

---

### Task: competitor-monitoring (毎日 07:00 JST に実行)

競合14社のWebサイト・機能変更モニタリング。

1. `check-competitor-updates` Edge Function で可用性チェック
2. WebSearch で各競合の最新ニュースを検索
3. `docs/competitor-reports/YYYY-MM-DD.md` にレポート作成
4. 重要な変更があれば GROWTH_STRATEGY_ROADMAP.md にも反映

---

### Task: infra-health-check (毎時30分に実行)

インフラヘルスチェック。

1. `health-check` Edge Function で DB・テーブル・レスポンスタイムを確認
2. Firebase Hosting (<https://my-web-app-b67f4.web.app/>) の可用性を確認
2. Firebase Hosting (https://my-web-app-b67f4.web.app/) の可用性を確認
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

#### Step 3: 投稿記録をSupabaseに保存

以下のSQLで `blog_posts` テーブルに下書きを登録:

```sql
INSERT INTO blog_posts (title, draft_path, status, target_platforms, created_at)
VALUES ('<タイトル案1>', 'docs/blog-drafts/YYYY-MM-DD.md', 'draft', ARRAY['zenn','qiita'], NOW())
ON CONFLICT DO NOTHING;
```

※ `blog_posts` テーブルのスキーマ:

```sql
id uuid, title text, draft_path text, status text (draft/posted/skipped),
target_platforms text[], posted_at timestamptz, url text, created_at timestamptz
```

#### Step 4: コミット

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
    comparison_page.dart # 競合比較ページ (14社)
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
| `get-growth-roadmap-progress` | 進捗バーデータ (15競合+短中長期) |
| `get-competitor-features` | 競合14社の機能比較データ |
| `health-check` | インフラヘルスチェック |
| `check-competitor-updates` | 競合14社のWebサイト可用性チェック |

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
