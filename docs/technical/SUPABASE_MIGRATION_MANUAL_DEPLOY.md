# Supabaseマイグレーション手動デプロイガイド

> **⚠️ アーカイブ済 (2026-04-12 Windows版#56 確認)**: このドキュメントは 2025年11月時点の手動デプロイ手順です。
> 現在は `deploy-prod.yml` による CI/CD 自動デプロイが稼働中。手順変更は `docs/CICD_SETUP_GUIDE.md` を参照してください。

**作成日**: 2025年11月8日
**対象**: 添付ファイル機能（attachments）のセットアップ

---

## 🚨 なぜ手動デプロイが必要か

### CLI（supabase db push）の問題

```bash
PS C:\Users\kanta\GitHub\my_web_app> supabase db push
Remote migration versions not found in local migrations directory.
```

**原因**:
- リモート（Supabase）には既に適用されているマイグレーションが、ローカルに存在しない
- マイグレーション履歴の不一致

**解決策**:
今回は**Supabase Dashboardで手動実行**が最も安全です。

---

## ✅ 手動デプロイ手順（5分）

### ステップ1: Supabase Dashboardにアクセス

1. https://app.supabase.com/ を開く
2. ログイン
3. プロジェクト「**my_web_app**」を選択

---

### ステップ2: SQL Editorを開く

1. 左側のメニューから「**SQL Editor**」をクリック
2. 「**New query**」ボタンをクリック

---

### ステップ3: SQLをコピー＆ペースト

以下のSQLをコピーして、SQL Editorに貼り付けてください：

**ファイル**: `supabase/migrations/20251108_attachments_setup.sql`

```sql
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
```

---

### ステップ4: SQLを実行

1. SQL Editorで「**Run**」ボタンをクリック
2. 実行完了を待つ（5-10秒）

---

### ステップ5: 実行結果の確認

**成功メッセージ**:
```
Success. No rows returned
```

または、個別のメッセージ：
```
CREATE TABLE
CREATE INDEX
CREATE INDEX
CREATE INDEX
ALTER TABLE
CREATE POLICY
CREATE POLICY
CREATE POLICY
CREATE POLICY
INSERT 0 1 (または INSERT 0 0 if already exists)
CREATE POLICY (x5)
CREATE FUNCTION
CREATE TRIGGER
CREATE FUNCTION
COMMENT
COMMENT (x9)
```

**エラーがある場合**:
- ポリシー名の重複エラー → 既に存在する（問題なし）
- テーブルの重複エラー → 既に存在する（問題なし）

---

### ステップ6: データベース確認

#### 6.1 attachmentsテーブルの確認

1. 左メニューから「**Table Editor**」をクリック
2. テーブル一覧から「**attachments**」を探す
3. ✅ テーブルが表示されることを確認

#### 6.2 attachmentsバケットの確認

1. 左メニューから「**Storage**」をクリック
2. バケット一覧から「**attachments**」を探す
3. ✅ バケットが表示されることを確認

#### 6.3 詳細確認（オプション）

**attachmentsテーブル**:
```sql
SELECT * FROM public.attachments LIMIT 1;
```
→ まだデータはないが、エラーが出なければOK

**Storage policies**:
- SQL Editorで以下を実行：
```sql
SELECT policyname FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%attachments%';
```
→ 5つのポリシーが表示されることを確認

---

## ✅ 動作テスト

### テスト手順

1. **アプリにログイン**
   - https://your-app-url.web.app にアクセス
   - ログイン

2. **メモを作成**
   - 新しいメモを作成
   - メモを保存

3. **ファイルを添付**
   - メモエディタで「添付ファイル」ボタンをクリック
   - 画像またはPDFを選択（5MB以下）
   - アップロードを実行

4. **確認項目**
   - [ ] `LateInitializationError`が発生しない
   - [ ] ファイル選択ダイアログが表示される
   - [ ] アップロード中のローディング表示
   - [ ] アップロード成功メッセージ
   - [ ] 添付ファイルが表示される
   - [ ] 添付ファイルをクリックしてプレビュー
   - [ ] 添付ファイルを削除できる

---

## 🔍 トラブルシューティング

### エラー1: テーブル作成エラー

```
ERROR: relation "attachments" already exists
```

**原因**: テーブルが既に存在する

**対処**: 問題なし（`CREATE TABLE IF NOT EXISTS`のため）

---

### エラー2: ポリシー作成エラー

```
ERROR: policy "Users can view their own attachments" for table "attachments" already exists
```

**原因**: ポリシーが既に存在する

**対処**:
1. 既存のポリシーを削除してから再実行
```sql
DROP POLICY IF EXISTS "Users can view their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can insert their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can update their own attachments" ON public.attachments;
DROP POLICY IF EXISTS "Users can delete their own attachments" ON public.attachments;

-- Storage policies
DROP POLICY IF EXISTS "Users can upload their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own files" ON storage.objects;
```

2. その後、元のSQLを再実行

---

### エラー3: バケット作成エラー

```
ERROR: duplicate key value violates unique constraint "buckets_pkey"
```

**原因**: バケットが既に存在する

**対処**: 問題なし（`ON CONFLICT (id) DO NOTHING`のため）

---

### エラー4: アップロード時の権限エラー

```
Error: new row violates row-level security policy
```

**原因**: RLSポリシーが正しく設定されていない

**対処**:
1. SQL Editorで確認：
```sql
SELECT * FROM pg_policies WHERE tablename = 'attachments';
```

2. ポリシーが存在しない場合、ステップ2のRLS設定部分を再実行

---

## 📚 参考情報

### 作成されるもの

**Database**:
- `public.attachments` テーブル
- 3つのインデックス
- 4つのRLSポリシー（attachments）
- 1つのトリガー関数
- 1つの統計取得関数

**Storage**:
- `attachments` バケット（プライベート、5MB制限）
- 4つのRLSポリシー（storage.objects）

---

## ✅ 完了チェックリスト

- [ ] SQL EditorでSQLを実行
- [ ] エラーがないことを確認
- [ ] attachmentsテーブルが存在することを確認
- [ ] attachmentsバケットが存在することを確認
- [ ] アプリでファイルアップロードをテスト
- [ ] ファイルが正常にアップロードされることを確認
- [ ] ファイルが正常に表示されることを確認
- [ ] ファイルが正常に削除されることを確認

---

**作成日**: 2025年11月8日
**最終更新**: 2025年11月8日
**ステータス**: ⏳ 手動デプロイ待ち
