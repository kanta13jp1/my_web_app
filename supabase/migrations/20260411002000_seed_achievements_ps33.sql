-- PowerShell版 Session #33: #75-#77 Discord/LINE/GitHub PR 通知連携ページ実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Discord 通知連携 (#75)', 'Discord Webhook URL設定・トリガー制御・履歴表示ページ実装。discord-notifications EFと連携。', '2026-04-11'),
  ('LINE 通知連携 (#76)', 'LINE Notifyアクセストークン設定・トリガー制御・履歴表示ページ実装。line-notifications EFと連携。', '2026-04-11'),
  ('GitHub PR 管理 (#77)', 'GitHub PAT・リポジトリ設定・PR一覧・統計表示ページ実装。github-pr-manager EFと連携。', '2026-04-11')
ON CONFLICT DO NOTHING;
