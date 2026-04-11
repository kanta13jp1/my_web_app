# 4インスタンス並列開発 — 競合防止ガイド

作成日: 2026-03-30
管理: PowerShell インスタンス (全体管理)

---

## インスタンス分担

| インスタンス | 担当領域 | 禁止領域 |
| --- | --- | --- |
| **VSCode** | `lib/` フロントエンド実装 (Dart/Flutter・205ページ) | `supabase/functions/`, `docs/` |
| **Web版** | `supabase/functions/` Edge Functions (Deno・241本) | `lib/`, `docs/` |
| **Windows版** | `docs/` ドキュメント・`supabase/migrations/` + seed SQL | `lib/`, `supabase/functions/` |
| **PowerShell** | `.github/workflows/` + CI/CD (16本) | 他3範囲 |

---

## 競合防止ルール

### 必須手順 (作業開始時)

```bash
git stash
git pull --rebase origin main
git stash pop
```

### コミット単位の原則

- 各インスタンスは担当領域のファイルのみ `git add` する
- `git add -A` や `git add .` は使わず、ファイル指定でステージング
- プッシュ前に `git status` で余分なファイルが含まれていないか確認

### マイグレーションファイルの番号帯 (重複防止)

同日に複数インスタンスが seed ファイルを作成すると version 番号が衝突する。
**各インスタンスは以下の番号帯を使用すること**:

| インスタンス | 番号帯 | 例 |
| --- | --- | --- |
| **Web / Schedule (自動)** | `000010` ~ `000499` | `20260401000040_seed_session432j.sql` |
| **VSCode** | `000500` ~ `000699` | `20260401000500_seed_vscode.sql` |
| **Windows** | `000700` ~ `000899` | `20260401000700_seed_windows.sql` |
| **PowerShell (全体管理)** | `000900` ~ `000999` | `20260401000900_seed_ps8_ps9.sql` |

> **注意**: `supabase/migrations/` の version は `schema_migrations` テーブルの PK。
> 重複があると `supabase db push` が `duplicate key value` エラーで失敗する。
> 衝突を発見したら PowerShell インスタンスが高い番号帯へリナンバーして即コミット。

### 競合が発生した場合

```bash
git rebase --continue   # コンフリクト解決後
git rebase --abort      # リベースをやめて元に戻す場合
```

---

## スケジュールタスク一覧 (Claude Code Schedule)

| タスク | スケジュール | 担当機能 |
| --- | --- | --- |
| `daily-report` | 毎日 09:00 JST | Actions生成レポート確認 → AI分析追記 → X投稿(失敗時のみ) |
| `cs-check` | 毎時 :07 | CS対応 / PR自動レビュー / ヘルスチェック |
| `github-issue-fix` | 毎日 10:00 JST | Open Issue → EF UI導線追加 / analyze エラー修正 → クローズ |
| `weekly-sns-draft` | 毎週月曜 09:00 JST | SNSドラフト + Zenn記事ネタ + 依存脆弱性チェック |
| `pr-auto-review` | 3時間毎 | セキュリティ/パフォ/バグ観点のPRレビュー |
| `competitor-monitoring` | 毎日 07:00 JST | 競合21社の可用性 + 最新ニュース調査 |
| `infra-health-check` | 毎時 :30 | `health-check` EF + Firebase Hosting 確認 |
| `dependency-audit` | 毎週月曜 08:00 JST | `pub outdated` + Deno import バージョン検査 |
| `blog-draft` | 毎日 08:00 JST | 直近7日コミット → ブログ下書き → `blog_posts` テーブル登録 |

> GitHub Actions と **並行・補完**する関係。Actions がデータ収集・投稿を担当し、Claude Schedule が AI分析・コード修正を担当。

---

## データベーステーブル管理

### 主要テーブル一覧

| テーブル | 用途 | 担当インスタンス |
| --- | --- | --- |
| `user_profiles` | ユーザープロフィール (is_admin含む) | PowerShell (スキーマ管理) |
| `schedule_task_runs` | Schedule実行ログ | PowerShell (スキーマ管理) |
| `blog_posts` | ブログ投稿管理 | PowerShell (スキーマ管理) |
| `development_achievements` | 開発実績 | Windows/PowerShell |
| `agents` / `agent_tasks` | 仮想AI組織 | PowerShell (スキーマ管理) |
| `teams` / `team_memberships` | チームワークスペース | PowerShell (スキーマ管理) |
| `growth_plans` | 競合比較進捗データ | Windows (データ更新) |

### RLS ポリシー設計原則

- `service_role`: 全テーブルで全操作可能 (Schedule タスクが使用)
- `authenticated` + `is_admin = true`: 管理者向けテーブル読み書き
- `auth.uid() = user_id`: 一般ユーザーの自己データアクセス

---

## よくあるエラーと対処法

### push が rejected された場合

```bash
git pull --rebase origin main
# コンフリクトを解決してから
git push origin main
```

### flutter analyze エラーが出た場合

```bash
flutter analyze lib/ 2>&1 | grep "error:" | head -20
```

エラーがある場合はそのファイルを修正してから commit する。

### Edge Function の呼び出しが失敗する場合

- Claude Code Web環境ではプロキシによりブロックされることがある
- その場合は git log ベースのフォールバックを使用する

---

## 実装済み機能チェックリスト

### Schedule タスクが自動実行する機能

- [x] 毎時: CS対応 (FAQ返信・バグ修正・エスカレーション)
- [x] 毎時: Edge Function UI カバレッジチェック・自動ページ生成
- [x] 毎時: GitHub PR 自動レビュー
- [x] 毎時: コードレビュー → GitHub Issue 自動発行
- [x] 毎時: インフラヘルスチェック
- [x] 毎日: 日次レポート生成 (schedule_task_runs 記録含む)
- [x] 毎日: X (@kanta13jp1) 自動投稿
- [x] 毎日: 競合モニタリング
- [x] 毎日: ブログ下書き自動生成 (Zenn/Qiita/note 等)
- [x] 毎週: SNS投稿ドラフト + 脆弱性チェック

### 管理者ダッシュボード機能

- [x] Schedule タスク実行状況 (ScheduleTaskMonitorCard)
- [x] 登録ユーザー管理 (get-admin-users Edge Function)
- [x] Edge Function 一覧 + UI導線状況 (EdgeFunctionStatusPage)
- [x] 競合モニタリング (CompetitorMonitoringCard)
- [x] 成長指標ダッシュボード (GrowthCommandCenter)
