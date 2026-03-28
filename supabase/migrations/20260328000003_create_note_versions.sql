-- note_versions: ノートのバージョン履歴テーブル
CREATE TABLE IF NOT EXISTS note_versions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id      bigint NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title        text NOT NULL DEFAULT '',
  content      text NOT NULL DEFAULT '',
  saved_at     timestamptz NOT NULL DEFAULT now()
);

-- ユーザーは自分のノートの履歴のみ参照可能
ALTER TABLE note_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own note versions"
  ON note_versions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own note versions"
  ON note_versions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own note versions"
  ON note_versions FOR DELETE
  USING (auth.uid() = user_id);

-- note_id + saved_at でクエリが速くなるようにインデックス
CREATE INDEX IF NOT EXISTS note_versions_note_id_saved_at_idx
  ON note_versions (note_id, saved_at DESC);
