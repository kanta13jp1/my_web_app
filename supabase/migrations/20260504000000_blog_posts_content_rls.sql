-- PS#5 S125: blog_posts content列追加 + RLS緩和 (SELECT全認証ユーザー)
-- Background: blog投稿管理UIが"動作していない"根本原因修正
--   1. blog_posts SELECT が admin-only → 通常ユーザーには0件表示 (silent catch で握り潰し)
--   2. content列がなく EFからUI経由で公開できない

ALTER TABLE blog_posts ADD COLUMN IF NOT EXISTS content text;

-- 既存の admin_all (ALL) policy を分解:
--   SELECT → 全認証ユーザーに開放 (GHA生成ドラフトを全ユーザーが閲覧可能に)
--   INSERT/UPDATE/DELETE → admin維持
DROP POLICY IF EXISTS "admin_all" ON blog_posts;

CREATE POLICY "admin_write" ON blog_posts
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.user_id = auth.uid()
      AND user_profiles.role = 'admin'
    )
  );

CREATE POLICY "authenticated_read" ON blog_posts
  FOR SELECT
  USING (auth.uid() IS NOT NULL);
