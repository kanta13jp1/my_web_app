-- Session: データベースビュー (Notion Database相当) 実装
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'テーブルデータビュー (Notion Database相当) 実装',
  'user_tables / user_table_rows テーブルをjsonbで動的スキーマ管理。カラム追加・削除、行のインライン編集、checkbox/date/select/number/text型対応。Flutter DataTableで横スクロール対応。/table-data ルート追加・ホームページナビゲーション追加。flutter analyze 0件維持。',
  '2026-03-28'
)
ON CONFLICT DO NOTHING;
