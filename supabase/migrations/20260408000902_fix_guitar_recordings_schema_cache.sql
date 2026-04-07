-- Fix: guitar_recordings スキーマキャッシュリロード + .m4a MIME タイプ対応
-- PostgREST が guitar_recordings テーブルを認識しない場合の修正。
-- storage bucket の allowed_mime_types に audio/x-m4a, video/mp4 を追加。

-- ─── テーブル確実に存在させる ────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.guitar_recordings (
  id                uuid         DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id           uuid         NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title             text         NOT NULL DEFAULT '無題の録音',
  duration_seconds  integer      NOT NULL DEFAULT 0,
  preset            text         NOT NULL DEFAULT 'acoustic_fingerpicking',
  tuning            text         NOT NULL DEFAULT 'standard',
  bpm               integer      NOT NULL DEFAULT 120,
  track_count       integer      NOT NULL DEFAULT 1,
  tags              text[]       NOT NULL DEFAULT '{}',
  is_public         boolean      NOT NULL DEFAULT false,
  likes             integer      NOT NULL DEFAULT 0,
  plays             integer      NOT NULL DEFAULT 0,
  file_url          text,
  duration_display  text,
  ai_feedback       text,
  file_path         text,
  file_mime_type    text,
  file_size_bytes   bigint,
  export_format     text         NOT NULL DEFAULT 'wav',
  created_at        timestamptz  NOT NULL DEFAULT now(),
  updated_at        timestamptz  NOT NULL DEFAULT now()
);

ALTER TABLE public.guitar_recordings
  ADD COLUMN IF NOT EXISTS file_path       text,
  ADD COLUMN IF NOT EXISTS file_mime_type  text,
  ADD COLUMN IF NOT EXISTS file_size_bytes bigint,
  ADD COLUMN IF NOT EXISTS export_format   text NOT NULL DEFAULT 'wav';

-- ─── RLS ─────────────────────────────────────────────────────────────────────

ALTER TABLE public.guitar_recordings ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'guitar_recordings'
      AND policyname = 'guitar_recordings_owner_all'
  ) THEN
    CREATE POLICY "guitar_recordings_owner_all"
      ON public.guitar_recordings FOR ALL
      USING  (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'guitar_recordings'
      AND policyname = 'guitar_recordings_public_read'
  ) THEN
    CREATE POLICY "guitar_recordings_public_read"
      ON public.guitar_recordings FOR SELECT
      USING (is_public = true);
  END IF;
END $$;

-- ─── Storage Bucket: .m4a / video/mp4 を追加 ─────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'guitar-recordings',
  'guitar-recordings',
  false,
  104857600,  -- 100 MB
  ARRAY[
    'audio/wav', 'audio/x-wav',
    'audio/mp4', 'audio/x-m4a', 'audio/m4a',
    'audio/aac',
    'audio/mpeg', 'audio/mp3',
    'audio/webm',
    'audio/ogg',
    'video/mp4'
  ]::text[]
)
ON CONFLICT (id) DO UPDATE
  SET allowed_mime_types = EXCLUDED.allowed_mime_types,
      file_size_limit    = EXCLUDED.file_size_limit;

-- ─── PostgREST スキーマキャッシュを強制リロード ───────────────────────────────

NOTIFY pgrst, 'reload schema';
