-- 添付ファイル機能の完全セットアップ
-- 既存のテーブル・ポリシーを削除して再作成
-- 作成日: 2025年11月8日

-- ================================
-- 0. 完全クリーンアップ
-- ================================

-- トリガーを削除
DROP TRIGGER IF EXISTS trigger_update_attachments_updated_at ON public.attachments;

-- 関数を削除
DROP FUNCTION IF EXISTS public.update_attachments_updated_at();
DROP FUNCTION IF EXISTS public.get_attachment_stats(UUID);

-- Database policies削除
DROP POLICY IF EXISTS "Users can view their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can insert their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can update their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can delete their own attachments" ON public.attachments;

-- Storage policies削除
DROP POLICY IF EXISTS "Users can upload their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;

-- テーブルを削除（データも削除されます）
DROP TABLE IF EXISTS public.attachments CASCADE;

-- ================================
-- 1. attachmentsテーブルの作成
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

-- インデックス作成
CREATE INDEX idx_attachments_note_id ON public.attachments(note_id);
CREATE INDEX idx_attachments_user_id ON public.attachments(user_id);
CREATE INDEX idx_attachments_created_at ON public.attachments(created_at DESC);

-- ================================
-- 2. RLS設定
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
-- 3. Storageバケット作成
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
-- 4. Storage RLSポリシー
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
-- 5. トリガー関数
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
-- 6. 統計関数
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
-- 7. コメント
-- ================================

COMMENT ON TABLE public.attachments IS '添付ファイルのメタデータを保存するテーブル';
COMMENT ON COLUMN public.attachments.id IS '添付ファイルID';
COMMENT ON COLUMN public.attachments.note_id IS 'メモID';
COMMENT ON COLUMN public.attachments.user_id IS 'ユーザーID';
COMMENT ON COLUMN public.attachments.file_name IS '元のファイル名';
COMMENT ON COLUMN public.attachments.file_path IS 'Storageパス';
COMMENT ON COLUMN public.attachments.file_size IS 'ファイルサイズ（バイト）';
COMMENT ON COLUMN public.attachments.file_type IS 'ファイルタイプ';
COMMENT ON COLUMN public.attachments.mime_type IS 'MIMEタイプ';
COMMENT ON COLUMN public.attachments.created_at IS '作成日時';
COMMENT ON COLUMN public.attachments.updated_at IS '更新日時';
