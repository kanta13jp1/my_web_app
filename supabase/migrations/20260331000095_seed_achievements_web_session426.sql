-- Session 426: Web版 feature-request-manager + app-analytics-dashboard (56 Functions)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Feature Request Manager Edge Function 追加', '機能リクエストの完全 CRUD + 投票 + ステータス管理 API。ユーザー認証付き投稿・投票機能、管理者ステータス更新、サマリービュー', '2026-03-31'),
  ('App Analytics Dashboard Edge Function 追加', 'アプリ分析ダッシュボード API。KPI 一覧 (ユーザー/ノート/実績/リクエスト/チケット/ブログ/通知)、日別トレンド、Edge Function 利用率', '2026-03-31')
ON CONFLICT DO NOTHING;
