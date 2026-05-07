-- nocheck:time-relative
-- blog_posts: created_by 追加 + anon public-read + user own-draft CRUD
-- Public reader (anon) → posted のみ閲覧可
-- Auth user  → 自分のドラフトを INSERT/UPDATE/DELETE 可

ALTER TABLE blog_posts
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS blog_posts_status_posted_at_idx
  ON blog_posts (status, posted_at DESC NULLS LAST);

-- anon が status='posted' の記事を閲覧できる
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'blog_posts' AND policyname = 'anon_read_posted'
  ) THEN
    CREATE POLICY anon_read_posted ON blog_posts
      FOR SELECT TO anon
      USING (status = 'posted');
  END IF;
END $$;

-- authenticated user が自分のドラフトを INSERT できる
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'blog_posts' AND policyname = 'user_insert_own_draft'
  ) THEN
    CREATE POLICY user_insert_own_draft ON blog_posts
      FOR INSERT TO authenticated
      WITH CHECK (auth.uid() = created_by AND status = 'draft');
  END IF;
END $$;

-- authenticated user が自分のドラフトを UPDATE できる
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'blog_posts' AND policyname = 'user_update_own_draft'
  ) THEN
    CREATE POLICY user_update_own_draft ON blog_posts
      FOR UPDATE TO authenticated
      USING (auth.uid() = created_by AND status = 'draft');
  END IF;
END $$;

-- authenticated user が自分のドラフトを DELETE できる
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'blog_posts' AND policyname = 'user_delete_own_draft'
  ) THEN
    CREATE POLICY user_delete_own_draft ON blog_posts
      FOR DELETE TO authenticated
      USING (auth.uid() = created_by AND status = 'draft');
  END IF;
END $$;
