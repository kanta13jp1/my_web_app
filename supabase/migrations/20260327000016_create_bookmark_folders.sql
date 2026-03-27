-- ブックマークフォルダ管理テーブル
CREATE TABLE IF NOT EXISTS bookmark_folders (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  folder_name text NOT NULL,
  platform text NOT NULL DEFAULT 'x',
  url text,
  is_organized boolean NOT NULL DEFAULT false,
  last_organized_at timestamptz,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bookmark_folders_user
  ON bookmark_folders (user_id);

ALTER TABLE bookmark_folders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own bookmark folders"
  ON bookmark_folders FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
