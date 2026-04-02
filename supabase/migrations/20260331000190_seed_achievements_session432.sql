-- Session 432 (Web版): Edge Functions 110→115 (5本追加)
-- wiki-database, api-key-manager, scheduled-notifications, cohort-analysis, integration-connector

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Wiki・データベース機能', 'Notion競合の階層ページ管理・テーブルビュー・親子関係・アイコン対応のWiki Edge Function実装', '2026-03-31'),
  ('APIキー管理機能', 'GitHub/Slack競合のAPIキー生成(jk_プレフィックス)・権限設定・使用量追跡・無効化機能を実装', '2026-03-31'),
  ('通知スケジューリング機能', 'Slack/Discord競合のリマインダー設定・定期通知(once/recurring)・通知キュー管理・自動発火機能を実装', '2026-03-31'),
  ('コホート分析機能', 'Google Analytics競合のユーザーコホート(登録月別)・DAUリテンション・ファネル分析・イベント集計を実装', '2026-03-31'),
  ('外部サービス連携機能', '10サービス(Slack/Discord/LINE/GitHub/Notion/Google Calendar/X/Chatwork/Google Drive/Dropbox)との連携管理・同期・ステータス確認を実装', '2026-03-31')
ON CONFLICT DO NOTHING;
