-- Session 430: time-tracker + expense-tracker + ai-summarizer + template-library + tag-manager
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Time Tracker Edge Function 追加', '勤怠・時間追跡。出退勤打刻/プロジェクト別時間記録/日週月集計/残業アラート', '2026-03-31'),
  ('Expense Tracker Edge Function 追加', '家計簿・経費管理。収支記録/12カテゴリ/月年レポート/予算管理・超過アラート', '2026-03-31'),
  ('AI Summarizer Edge Function 追加', 'AIテキスト要約。要約/キーポイント抽出/感情分析/アクションアイテム抽出', '2026-03-31'),
  ('Template Library Edge Function 追加', 'テンプレートライブラリ。8組込テンプレート/カスタム作成/カテゴリ別/使用ログ', '2026-03-31'),
  ('Tag Manager Edge Function 追加', 'タグ管理。統計/自動提案/タグマージ/一括追加・削除', '2026-03-31')
ON CONFLICT DO NOTHING;
