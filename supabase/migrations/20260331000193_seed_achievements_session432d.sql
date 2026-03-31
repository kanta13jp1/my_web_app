-- Session 432d (Web版): Edge Functions 125→130 (5本追加)
-- spreadsheet-database, gantt-timeline-manager, whiteboard-canvas, form-builder, meeting-manager

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('スプレッドシート・データベース', 'Google Sheets/Notion Databases/Airtable競合の列定義(11型)・行CRUD・フィルタ・ソート・ビュー切替(table/gallery/board/list/calendar)を実装', '2026-03-31'),
  ('ガントチャート・タイムライン管理', 'Microsoft Project/GitHub Projects競合のプロジェクト管理・タスク依存関係・マイルストーン・クリティカルパス計算を実装', '2026-03-31'),
  ('ホワイトボード・キャンバス', 'Microsoft Whiteboard/Miro/FigJam競合の無限キャンバス・9要素タイプ・8テンプレート・リアルタイム共有を実装', '2026-03-31'),
  ('フォームビルダー', 'Google Forms/Microsoft Forms/Notion Forms競合の16フィールドタイプ・条件分岐・公開URL回答収集・回答集計分析を実装', '2026-03-31'),
  ('ミーティング管理', 'Google Meet/Teams/Slack Huddles競合のミーティングRSVP・アジェンダ・議事録・アクションアイテム抽出を実装', '2026-03-31')
ON CONFLICT DO NOTHING;
