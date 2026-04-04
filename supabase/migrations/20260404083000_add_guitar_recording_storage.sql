-- Guitar recording storage support
-- Adds metadata columns for stored audio files and provisions a dedicated
-- private Storage bucket so browser uploads can be kept in sync with
-- guitar_recordings.

ALTER TABLE public.guitar_recordings
  ADD COLUMN IF NOT EXISTS file_path text,
  ADD COLUMN IF NOT EXISTS file_mime_type text,
  ADD COLUMN IF NOT EXISTS file_size_bytes bigint,
  ADD COLUMN IF NOT EXISTS export_format text NOT NULL DEFAULT 'wav';

COMMENT ON COLUMN public.guitar_recordings.file_path IS
  'Supabase Storage object path for the saved recording';
COMMENT ON COLUMN public.guitar_recordings.file_mime_type IS
  'Stored recording MIME type';
COMMENT ON COLUMN public.guitar_recordings.file_size_bytes IS
  'Stored recording file size in bytes';
COMMENT ON COLUMN public.guitar_recordings.export_format IS
  'Primary export container/extension used for sharing and playback';

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'guitar-recordings',
  'guitar-recordings',
  false,
  52428800,
  ARRAY[
    'audio/wav',
    'audio/x-wav',
    'audio/mp4',
    'audio/aac',
    'audio/mpeg',
    'audio/webm',
    'audio/ogg'
  ]::text[]
)
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
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
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
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
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
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
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'storage'
      AND tablename = 'objects'
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
