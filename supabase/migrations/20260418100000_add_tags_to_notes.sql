-- ノートタグ機能 (β版向け Notion対抗)
ALTER TABLE notes ADD COLUMN IF NOT EXISTS tags text[] NOT NULL DEFAULT '{}';
CREATE INDEX IF NOT EXISTS idx_notes_tags ON notes USING gin(tags);
