# 4インスタンス並列開発 — 競合防止ガイド

作成日: 2026-03-30
管理: PowerShell インスタンス (全体管理)

---

## インスタンス分担

| インスタンス | 担当領域 | 禁止領域 |
|------------|---------|---------|
| **VSCode** | `lib/` フロントエンド実装 (Dart/Flutter) | `supabase/functions/`, `docs/` |
| **Web版** | `supabase/functions/` Edge Functions (Deno) | `lib/`, `docs/` |
| **Windows版** | `docs/` ドキュメント・`supabase/migrations/` | `lib/`, `supabase/functions/` |
| **PowerShell** | 全体管理・マイグレーション・ロードマップ・スケジュール | (全体を俯瞰、緊急時に横断対応可) |

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

### 競合が発生した場合

```bash
git rebase --continue   # コンフリクト解決後
git rebase --abort      # リベースをやめて元に戻す場合
```

---

## スケジュールタスク一覧 (Claude Code Schedule)

| タスク | スケジュール | 担当機能 |
|--------|------------|---------|
| `cs-check` | 毎時 00分 | CS対応 / Edge UI同期 / Issue自動修正 / PR review / ヘルスチェック |
| `daily-report` | 毎日 09:00 JST | 日次レポート / X投稿 / 競合監視 / Schedule健全性チェック |
| `blog-draft` | 毎日 08:00 JST | ブログ下書き自動生成 / 投稿管理 |
| `weekly-sns-draft` | 毎週月曜 09:00 JST | SNSドラフト / 脆弱性チェック |

> **上限**: 現在4件で上限に達しています。新規追加には既存タスクの削除が必要。

---

## データベーステーブル管理

### 主要テーブル一覧

| テーブル | 用途 | 担当インスタンス |
|---------|------|---------------|
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
