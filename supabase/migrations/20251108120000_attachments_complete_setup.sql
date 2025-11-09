-- Attachments feature complete setup
-- Drop existing tables and policies then recreate
-- Created: 2025-11-08

-- ================================
-- 0. Complete Cleanup
-- ================================

-- Drop triggers
DROP TRIGGER IF EXISTS trigger_update_attachments_updated_at ON public.attachments;

-- Drop functions
DROP FUNCTION IF EXISTS public.update_attachments_updated_at();
DROP FUNCTION IF EXISTS public.get_attachment_stats(UUID);

-- Drop Database policies
DROP POLICY IF EXISTS "Users can view their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can insert their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can update their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can delete their own attachments" ON public.attachments;

-- Drop Storage policies
DROP POLICY IF EXISTS "Users can upload their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;

-- Drop table (data will be deleted)
DROP TABLE IF EXISTS public.attachments CASCADE;

-- ================================
-- 1. Create attachments table
-- ================================

CREATE TABLE public.attachments (
  id BIGSERIAL PRIMARY KEY,
  note_id BIGINT NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL UNIQUE,
  file_size BIGINT NOT NULL,
  file_type TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes
CREATE INDEX idx_attachments_note_id ON public.attachments(note_id);
CREATE INDEX idx_attachments_user_id ON public.attachments(user_id);
CREATE INDEX idx_attachments_created_at ON public.attachments(created_at DESC);

-- ================================
-- 2. RLS Setup
-- ================================

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own attachments"
  ON public.attachments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own attachments"
  ON public.attachments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own attachments"
  ON public.attachments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own attachments"
  ON public.attachments FOR DELETE
  USING (auth.uid() = user_id);

-- ================================
-- 3. Create Storage bucket
-- ================================

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'attachments',
  'attachments',
  false,
  5242880,
  ARRAY['image/jpeg','image/jpg','image/png','image/gif','image/webp','application/pdf']::text[]
)
ON CONFLICT (id) DO NOTHING;

-- ================================
-- 4. Storage RLS policies
-- ================================

CREATE POLICY "Users can upload their own files"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can view their own files"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can update their own files"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can delete their own files"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ================================
-- 5. Trigger functions
-- ================================

CREATE FUNCTION public.update_attachments_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_attachments_updated_at
  BEFORE UPDATE ON public.attachments
  FOR EACH ROW
  EXECUTE FUNCTION public.update_attachments_updated_at();

-- ================================
-- 6. Statistics function
-- ================================

CREATE FUNCTION public.get_attachment_stats(p_user_id UUID)
RETURNS TABLE(
  total_attachments BIGINT,
  total_size BIGINT,
  image_count BIGINT,
  pdf_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT,
    COALESCE(SUM(file_size), 0)::BIGINT,
    COUNT(*) FILTER (WHERE file_type = 'image')::BIGINT,
    COUNT(*) FILTER (WHERE file_type = 'pdf')::BIGINT
  FROM public.attachments
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================
-- 7. Comments
-- ================================

COMMENT ON TABLE public.attachments IS 'Stores metadata for file attachments';
COMMENT ON COLUMN public.attachments.id IS 'Attachment ID';
COMMENT ON COLUMN public.attachments.note_id IS 'Note ID';
COMMENT ON COLUMN public.attachments.user_id IS 'User ID';
COMMENT ON COLUMN public.attachments.file_name IS 'Original filename';
COMMENT ON COLUMN public.attachments.file_path IS 'Storage path';
COMMENT ON COLUMN public.attachments.file_size IS 'File size in bytes';
COMMENT ON COLUMN public.attachments.file_type IS 'File type';
COMMENT ON COLUMN public.attachments.mime_type IS 'MIME type';
COMMENT ON COLUMN public.attachments.created_at IS 'Created timestamp';
COMMENT ON COLUMN public.attachments.updated_at IS 'Updated timestamp';
