-- blog_posts RLS ポリシー修正
-- user_profiles.role は存在しないため is_admin = true に修正

DROP POLICY IF EXISTS "admin_all" ON blog_posts;

-- service_role は全操作可能
DROP POLICY IF EXISTS "service_role_blog_posts" ON blog_posts;
CREATE POLICY "service_role_blog_posts"
  ON blog_posts
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- 管理者 (is_admin = true) は全操作可能
DROP POLICY IF EXISTS "admin_all_blog_posts" ON blog_posts;
CREATE POLICY "admin_all_blog_posts"
  ON blog_posts
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM user_profiles up
      WHERE up.user_id = auth.uid()
        AND up.is_admin = true
    )
  );
