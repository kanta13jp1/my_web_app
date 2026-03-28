-- note_comments: ノートへのコメント機能テーブル
CREATE TABLE IF NOT EXISTS note_comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id    bigint NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content    text NOT NULL CHECK (length(trim(content)) > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ユーザーは自分のノートのコメントのみ参照・操作可能
ALTER TABLE note_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own note comments"
  ON note_comments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own note comments"
  ON note_comments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own note comments"
  ON note_comments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own note comments"
  ON note_comments FOR DELETE
  USING (auth.uid() = user_id);

-- クエリ高速化インデックス
CREATE INDEX IF NOT EXISTS note_comments_note_id_created_at_idx
  ON note_comments (note_id, created_at ASC);
