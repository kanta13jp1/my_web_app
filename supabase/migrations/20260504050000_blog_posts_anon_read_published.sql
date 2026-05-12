-- PS#3 S154: blog_posts 公開記事を anon ユーザーにも開放
-- 目的: サイト内公式ブログ (/blog) をログイン不要で閲覧可能にする
-- status='posted' の記事のみ公開 (draft/ready/skipped は非公開維持)

CREATE POLICY "public_read_published" ON blog_posts
  FOR SELECT
  TO anon, authenticated
  USING (status = 'posted');
