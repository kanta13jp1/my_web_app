-- 添付ファイル機能のセットアップ
-- 作成日: 2025年11月8日

-- ================================
-- 1. attachmentsテーブルの作成
-- ================================

CREATE TABLE IF NOT EXISTS public.attachments (
  id BIGSERIAL PRIMARY KEY,
  note_id BIGINT NOT NULL REFERENCES public.notes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  file_name TEXT NOT NULL,
  file_path TEXT NOT NULL UNIQUE,
  file_size BIGINT NOT NULL,
  file_type TEXT NOT NULL, -- 'image', 'pdf', 'other'
  mime_type TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- インデックス作成
CREATE INDEX IF NOT EXISTS idx_attachments_note_id ON public.attachments(note_id);
CREATE INDEX IF NOT EXISTS idx_attachments_user_id ON public.attachments(user_id);
CREATE INDEX IF NOT EXISTS idx_attachments_created_at ON public.attachments(created_at DESC);

-- ================================
-- 2. RLS（Row Level Security）設定
-- ================================

ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;

-- ユーザーは自分の添付ファイルのみ閲覧可能
CREATE POLICY "Users can view their own attachments"
  ON public.attachments
  FOR SELECT
  USING (auth.uid() = user_id);

-- ユーザーは自分の添付ファイルのみ挿入可能
CREATE POLICY "Users can insert their own attachments"
  ON public.attachments
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ユーザーは自分の添付ファイルのみ更新可能
CREATE POLICY "Users can update their own attachments"
  ON public.attachments
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ユーザーは自分の添付ファイルのみ削除可能
CREATE POLICY "Users can delete their own attachments"
  ON public.attachments
  FOR DELETE
  USING (auth.uid() = user_id);

-- ================================
-- 3. Storageバケットの作成
-- ================================

-- attachmentsバケットを作成（既に存在する場合はスキップ）
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'attachments',
  'attachments',
  false, -- プライベートバケット
  5242880, -- 5MB (5 * 1024 * 1024)
  ARRAY[
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf'
  ]::text[]
)
ON CONFLICT (id) DO NOTHING;

-- ================================
-- 4. Storage RLSポリシーの作成
-- ================================

-- ユーザーは自分のファイルのみアップロード可能
CREATE POLICY "Users can upload their own files"
  ON storage.objects
  FOR INSERT
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ユーザーは自分のファイルのみ閲覧可能
CREATE POLICY "Users can view their own files"
  ON storage.objects
  FOR SELECT
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ユーザーは自分のファイルのみ更新可能
CREATE POLICY "Users can update their own files"
  ON storage.objects
  FOR UPDATE
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ユーザーは自分のファイルのみ削除可能
CREATE POLICY "Users can delete their own files"
  ON storage.objects
  FOR DELETE
  USING (
    bucket_id = 'attachments'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ================================
-- 5. トリガー関数（updated_atの自動更新）
-- ================================

CREATE OR REPLACE FUNCTION public.update_attachments_updated_at()
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
-- 6. 便利な関数
-- ================================

-- 添付ファイルの統計を取得
CREATE OR REPLACE FUNCTION public.get_attachment_stats(p_user_id UUID)
RETURNS TABLE(
  total_attachments BIGINT,
  total_size BIGINT,
  image_count BIGINT,
  pdf_count BIGINT
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT AS total_attachments,
    COALESCE(SUM(file_size), 0)::BIGINT AS total_size,
    COUNT(*) FILTER (WHERE file_type = 'image')::BIGINT AS image_count,
    COUNT(*) FILTER (WHERE file_type = 'pdf')::BIGINT AS pdf_count
  FROM public.attachments
  WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ================================
-- 7. コメント追加
-- ================================

COMMENT ON TABLE public.attachments IS '添付ファイルのメタデータを保存するテーブル';
COMMENT ON COLUMN public.attachments.id IS '添付ファイルID';
COMMENT ON COLUMN public.attachments.note_id IS 'メモID（外部キー）';
COMMENT ON COLUMN public.attachments.user_id IS 'ユーザーID（外部キー）';
COMMENT ON COLUMN public.attachments.file_name IS '元のファイル名';
COMMENT ON COLUMN public.attachments.file_path IS 'Storageでのファイルパス（一意）';
COMMENT ON COLUMN public.attachments.file_size IS 'ファイルサイズ（バイト）';
COMMENT ON COLUMN public.attachments.file_type IS 'ファイルタイプ（image/pdf/other）';
COMMENT ON COLUMN public.attachments.mime_type IS 'MIMEタイプ';
COMMENT ON COLUMN public.attachments.created_at IS '作成日時';
COMMENT ON COLUMN public.attachments.updated_at IS '更新日時';
