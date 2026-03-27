-- 「我が闘争」コラム保存テーブル
CREATE TABLE IF NOT EXISTS my_struggle_columns (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '我が闘争',
  column_text text NOT NULL,
  context_data jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_my_struggle_columns_user_date
  ON my_struggle_columns (user_id, created_at DESC);

ALTER TABLE my_struggle_columns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own struggle columns"
  ON my_struggle_columns FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
