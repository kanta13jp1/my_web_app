-- Session 428 batch 2: team-collaboration-sync + user-feedback-collector + revenue-forecaster
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Team Collaboration Sync Edge Function 追加', 'チーム協業・アクティビティフィード・メンション通知・外部サービス通知ブリッジ', '2026-03-31'),
  ('User Feedback Collector Edge Function 追加', 'NPS (Net Promoter Score)・機能満足度・フリーテキストフィードバック収集・集計', '2026-03-31'),
  ('Revenue Forecaster Edge Function 追加', '月次/年次収益予測・カスタムシミュレーション・ブレークイーブンポイント算出・KPI目標', '2026-03-31')
ON CONFLICT DO NOTHING;
