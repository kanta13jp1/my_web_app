-- ユーザーデータベーステーブル (Notion Database 相当)
-- テーブル定義 (columns は jsonb で管理)
CREATE TABLE IF NOT EXISTS user_tables (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  title      text        NOT NULL DEFAULT '新しいデータベース',
  icon       text        DEFAULT '📊',
  columns    jsonb       NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE user_tables ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_tables_own" ON user_tables
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- テーブル行データ
CREATE TABLE IF NOT EXISTS user_table_rows (
  id         uuid        DEFAULT gen_random_uuid() PRIMARY KEY,
  table_id   uuid        REFERENCES user_tables(id) ON DELETE CASCADE NOT NULL,
  user_id    uuid        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  row_data   jsonb       NOT NULL DEFAULT '{}'::jsonb,
  sort_order int         DEFAULT 0,
  created_at timestamptz DEFAULT now() NOT NULL
);

ALTER TABLE user_table_rows ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_table_rows_own" ON user_table_rows
  FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_user_tables_user_id     ON user_tables(user_id);
CREATE INDEX IF NOT EXISTS idx_user_table_rows_table_id ON user_table_rows(table_id);
CREATE INDEX IF NOT EXISTS idx_user_table_rows_user_id  ON user_table_rows(user_id);
