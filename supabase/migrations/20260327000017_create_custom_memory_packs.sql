-- カスタム暗記セットテーブル
CREATE TABLE IF NOT EXISTS custom_memory_packs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  category text NOT NULL DEFAULT 'カスタム',
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_custom_memory_packs_user
  ON custom_memory_packs (user_id);

ALTER TABLE custom_memory_packs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own memory packs"
  ON custom_memory_packs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
