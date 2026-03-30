-- 管理者フラグ・プロフィール完成度トラッキング
-- PowerShell インスタンス (全体管理) 2026-03-30

-- is_admin フラグを user_profiles に追加
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

-- プロフィール完成度スコア (0-100) を追加
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS profile_completeness INT NOT NULL DEFAULT 0;

-- 最終ログイン日時 (admin 管理用)
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ;

-- service_role は全プロフィールを読み書き可能
DROP POLICY IF EXISTS "service_role_full_access_user_profiles" ON user_profiles;
CREATE POLICY "service_role_full_access_user_profiles"
  ON user_profiles
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- 管理者 (is_admin=true) は全プロフィールを閲覧可能
DROP POLICY IF EXISTS "admin_read_all_profiles" ON user_profiles;
CREATE POLICY "admin_read_all_profiles"
  ON user_profiles
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles up2
      WHERE up2.user_id = auth.uid() AND up2.is_admin = true
    )
  );

-- プロフィール完成度自動計算関数
CREATE OR REPLACE FUNCTION calculate_profile_completeness(p user_profiles)
RETURNS INT AS $$
DECLARE
  score INT := 0;
BEGIN
  -- display_name: 20点
  IF p.display_name IS NOT NULL AND length(p.display_name) > 0 THEN
    score := score + 20;
  END IF;
  -- bio: 20点
  IF p.bio IS NOT NULL AND length(p.bio) > 0 THEN
    score := score + 20;
  END IF;
  -- avatar_url: 20点
  IF p.avatar_url IS NOT NULL AND length(p.avatar_url) > 0 THEN
    score := score + 20;
  END IF;
  -- website_url: 15点
  IF p.website_url IS NOT NULL AND length(p.website_url) > 0 THEN
    score := score + 15;
  END IF;
  -- location: 10点
  IF p.location IS NOT NULL AND length(p.location) > 0 THEN
    score := score + 10;
  END IF;
  -- twitter_handle or github_handle: 15点
  IF (p.twitter_handle IS NOT NULL AND length(p.twitter_handle) > 0)
     OR (p.github_handle IS NOT NULL AND length(p.github_handle) > 0) THEN
    score := score + 15;
  END IF;
  RETURN score;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- プロフィール更新時に completeness を自動計算するトリガー
CREATE OR REPLACE FUNCTION update_profile_completeness()
RETURNS TRIGGER AS $$
BEGIN
  NEW.profile_completeness := calculate_profile_completeness(NEW);
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_profile_completeness ON user_profiles;
CREATE TRIGGER trg_update_profile_completeness
  BEFORE INSERT OR UPDATE ON user_profiles
  FOR EACH ROW EXECUTE FUNCTION update_profile_completeness();

COMMENT ON COLUMN user_profiles.is_admin IS '管理者フラグ。管理者ダッシュボードへのアクセス権を付与。';
COMMENT ON COLUMN user_profiles.profile_completeness IS 'プロフィール完成度 (0-100)。未完の場合はUI側でプロフィール更新を促す。';
COMMENT ON COLUMN user_profiles.last_login_at IS '最終ログイン日時。管理者が非アクティブユーザーを識別するために使用。';
