-- Session 21: Claude Code Schedule 自動化実装

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'Claude Code Schedule 自動化: 日次レポート・CS自動チェック・週次SNSドラフト生成',
    'schedule-daily-digest Edge Function 実装 (総ユーザー数・新規FR・未対応FR・直近実績を返すGET API)。CLAUDE.md 作成 (daily-report/cs-check/weekly-sns-draft の3スケジュールタスク定義)。docs/daily-reports/, docs/cs-notes/, docs/weekly-drafts/ ディレクトリ作成。deploy-prod.yml に schedule-daily-digest 追加。Claude Code Schedule でスケジュール登録 (日次09:00 JST + 毎時 + 週次月曜)',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
