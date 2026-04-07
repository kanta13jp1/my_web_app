-- Fix: guitar_recordings table and guitar-recordings storage bucket
-- This migration is fully idempotent (IF NOT EXISTS / ON CONFLICT DO NOTHING).
-- Ensures the table and bucket exist even if the original migrations were
-- incorrectly skipped by the CI/CD repair loop.

-- ─── Table ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS guitar_recordings (
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

-- Idempotent column additions (no-op if already present)
ALTER TABLE guitar_recordings
  ADD COLUMN IF NOT EXISTS file_path       text,
  ADD COLUMN IF NOT EXISTS file_mime_type  text,
  ADD COLUMN IF NOT EXISTS file_size_bytes bigint,
  ADD COLUMN IF NOT EXISTS export_format   text NOT NULL DEFAULT 'wav';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_guitar_recordings_user_id
  ON guitar_recordings (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_guitar_recordings_public
  ON guitar_recordings (is_public, created_at DESC)
  WHERE is_public = true;

-- RLS
ALTER TABLE guitar_recordings ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'guitar_recordings'
      AND policyname = 'guitar_recordings_owner_all'
  ) THEN
    CREATE POLICY "guitar_recordings_owner_all"
      ON guitar_recordings FOR ALL
      USING  (auth.uid() = user_id)
      WITH CHECK (auth.uid() = user_id);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'guitar_recordings'
      AND policyname = 'guitar_recordings_public_read'
  ) THEN
    CREATE POLICY "guitar_recordings_public_read"
      ON guitar_recordings FOR SELECT
      USING (is_public = true);
  END IF;
END $$;

-- updated_at trigger
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

-- ─── Storage Bucket ──────────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'guitar-recordings',
  'guitar-recordings',
  false,
  52428800,
  ARRAY[
    'audio/wav', 'audio/x-wav', 'audio/mp4',
    'audio/aac', 'audio/mpeg', 'audio/webm', 'audio/ogg'
  ]::text[]
)
ON CONFLICT (id) DO NOTHING;

-- Storage RLS policies
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Users can upload their own guitar recordings'
  ) THEN
    CREATE POLICY "Users can upload their own guitar recordings"
      ON storage.objects FOR INSERT
      WITH CHECK (
        bucket_id = 'guitar-recordings'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Users can view their own guitar recordings'
  ) THEN
    CREATE POLICY "Users can view their own guitar recordings"
      ON storage.objects FOR SELECT
      USING (
        bucket_id = 'guitar-recordings'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Users can update their own guitar recordings'
  ) THEN
    CREATE POLICY "Users can update their own guitar recordings"
      ON storage.objects FOR UPDATE
      USING (
        bucket_id = 'guitar-recordings'
        AND (storage.foldername(name))[1] = auth.uid()::text
      )
      WITH CHECK (
        bucket_id = 'guitar-recordings'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage' AND tablename = 'objects'
      AND policyname = 'Users can delete their own guitar recordings'
  ) THEN
    CREATE POLICY "Users can delete their own guitar recordings"
      ON storage.objects FOR DELETE
      USING (
        bucket_id = 'guitar-recordings'
        AND (storage.foldername(name))[1] = auth.uid()::text
      );
  END IF;
END $$;
