-- app_feedback テーブル: ユーザーからのフィードバック収集
-- FeedbackPage (lib/pages/feedback_page.dart) および
-- FeedbackListPage (lib/pages/admin/feedback_list_page.dart) が使用

CREATE TABLE IF NOT EXISTS app_feedback (
  id bigserial PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  category text NOT NULL DEFAULT 'other', -- 'feature' | 'bug' | 'other'
  content text NOT NULL,
  status text NOT NULL DEFAULT 'new',     -- 'new' | 'reviewed' | 'implemented'
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- インデックス
CREATE INDEX IF NOT EXISTS idx_app_feedback_user_id ON app_feedback(user_id);
CREATE INDEX IF NOT EXISTS idx_app_feedback_status ON app_feedback(status);
CREATE INDEX IF NOT EXISTS idx_app_feedback_created_at ON app_feedback(created_at DESC);

-- RLS 有効化
ALTER TABLE app_feedback ENABLE ROW LEVEL SECURITY;

-- ログイン済みユーザーは自分のフィードバックを投稿可
CREATE POLICY "users_insert_own_feedback" ON app_feedback
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ログイン済みユーザーは自分のフィードバックを閲覧可
CREATE POLICY "users_select_own_feedback" ON app_feedback
  FOR SELECT
  USING (auth.uid() = user_id);

-- 管理者は全件閲覧・更新可 (is_user_admin 関数は 20260331000060 で定義済み)
CREATE POLICY "admin_select_all_feedback" ON app_feedback
  FOR SELECT
  USING (is_user_admin(auth.uid()));

CREATE POLICY "admin_update_all_feedback" ON app_feedback
  FOR UPDATE
  USING (is_user_admin(auth.uid()))
  WITH CHECK (is_user_admin(auth.uid()));

-- updated_at 自動更新トリガー
CREATE OR REPLACE FUNCTION update_app_feedback_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_app_feedback_updated_at ON app_feedback;
CREATE TRIGGER trg_app_feedback_updated_at
  BEFORE UPDATE ON app_feedback
  FOR EACH ROW EXECUTE FUNCTION update_app_feedback_updated_at();
