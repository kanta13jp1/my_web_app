-- Session daily-dev#3: Notion インポート強化 (DB対応 + UI改善)
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Notion インポート強化 (DB対応)', 'growth-import-preview EFにデータベースエントリ取得を追加。プロパティ型別変換(select/multi_select/checkbox/number/date)とソースタイプバッジ表示をFlutter UIに実装。', '2026-04-11')
ON CONFLICT DO NOTHING;
