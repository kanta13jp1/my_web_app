-- Session 24: 自動化オペレーション UI / X手動投稿テスト / CS返信導線

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '自動化オペレーションUI追加・CS返信導線強化・X投稿テスト対応',
    'AdminAnalyticsPage に自動化オペレーションカードを追加し、schedule-daily-digest / get-support-tickets を管理画面から手動確認可能にした。reply-support-request を返信ダイアログ/エスカレーション対応へ拡張し、エスカレーション時は in_progress へ自動遷移。post-x-update に dryRun を追加し、@kanta13jp1 へのプレビュー/本番投稿を管理画面から実行できるようにした。自動化系 Edge Function には automation-auth ヘルパーを導入し、SERVICE_ROLE_KEY または allowlist 済み管理者ユーザーで認可する構成に整理。',
    '2026-03-26'
  )
ON CONFLICT DO NOTHING;
