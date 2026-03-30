-- PowerShell 全体管理セッション実績シード 2026-03-30

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Claude Code Schedule 4タスク体制確立',
    'daily-report・cs-check・blog-draft・weekly-sns-draft の4スケジュールタスクを登録。毎時CS対応、毎日AI日次レポート・ブログ下書き、毎週SNSドラフト自動化を実現。',
    '2026-03-30'
  ),
  (
    '管理者ユーザー管理強化 (is_admin・プロフィール完成度)',
    'user_profiles に is_admin フラグ・profile_completeness スコア・last_login_at を追加。管理者ダッシュボードで全ユーザーのプロフィール完成度を可視化し、更新促進UIを実装。',
    '2026-03-30'
  ),
  (
    'schedule_task_runs テーブル・Schedule監視ダッシュボード実装',
    'Claude Code Schedule の実行ログを schedule_task_runs テーブルに記録し、管理者ダッシュボードの ScheduleTaskMonitorCard で実行状況をリアルタイム表示。エラー時の自己修復フローも cs-check に統合。',
    '2026-03-30'
  ),
  (
    'PowerShell 4インスタンス並列開発体制確立',
    'VSCode(lib/フロントエンド) / Web(supabase/functions/) / Windows(docs/マイグレーション) / PowerShell(全体管理) の4インスタンス並列開発体制を確立。git pull --rebase による競合防止ルールを整備。',
    '2026-03-30'
  )
ON CONFLICT (title) DO NOTHING;
