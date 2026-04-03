-- ギター録音専用テーブル
-- app_analytics JSONB からの移行。型安全・高速クエリ・ユーザーFK対応。

CREATE TABLE IF NOT EXISTS guitar_recordings (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL DEFAULT '無題の録音',
  duration_seconds integer NOT NULL DEFAULT 0,
  preset text NOT NULL DEFAULT 'acoustic_fingerpicking',
  tuning text NOT NULL DEFAULT 'standard',
  bpm integer NOT NULL DEFAULT 120,
  track_count integer NOT NULL DEFAULT 1,
  tags text[] NOT NULL DEFAULT '{}',
  is_public boolean NOT NULL DEFAULT false,
  likes integer NOT NULL DEFAULT 0,
  plays integer NOT NULL DEFAULT 0,
  file_url text,           -- Supabase Storage URL (将来の音声ファイル保存用)
  duration_display text,   -- "2:34" 形式の表示用
  ai_feedback text,        -- AI コーチからのフィードバック
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_guitar_recordings_user_id
  ON guitar_recordings (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_guitar_recordings_public
  ON guitar_recordings (is_public, created_at DESC)
  WHERE is_public = true;

CREATE INDEX IF NOT EXISTS idx_guitar_recordings_preset
  ON guitar_recordings (preset);

-- RLS
ALTER TABLE guitar_recordings ENABLE ROW LEVEL SECURITY;

-- 本人のみ全操作可能
CREATE POLICY "guitar_recordings_owner_all"
  ON guitar_recordings FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 公開録音は全員が読める
CREATE POLICY "guitar_recordings_public_read"
  ON guitar_recordings FOR SELECT
  USING (is_public = true);

-- updated_at 自動更新
CREATE OR REPLACE FUNCTION update_guitar_recordings_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guitar_recordings_updated_at ON guitar_recordings;
CREATE TRIGGER guitar_recordings_updated_at
  BEFORE UPDATE ON guitar_recordings
  FOR EACH ROW EXECUTE FUNCTION update_guitar_recordings_updated_at();

COMMENT ON TABLE guitar_recordings IS 'ギター録音スタジオのレコーディング保存テーブル';
COMMENT ON COLUMN guitar_recordings.file_url IS 'Supabase Storage の公開URL (将来実装)';
COMMENT ON COLUMN guitar_recordings.ai_feedback IS 'AI ギターコーチからの練習フィードバック';
