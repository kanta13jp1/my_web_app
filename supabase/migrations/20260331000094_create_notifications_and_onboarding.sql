-- Session 425: app_notifications テーブル + user_profiles onboarding フィールド

-- 通知テーブル
CREATE TABLE IF NOT EXISTS app_notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE, -- null = 全員向け
  title text NOT NULL,
  message text NOT NULL,
  type text NOT NULL DEFAULT 'system', -- feature_update | achievement | cs_reply | system | marketing | blog_published | agent_report
  link text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_app_notifications_user ON app_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_app_notifications_read ON app_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_app_notifications_type ON app_notifications(type);

ALTER TABLE app_notifications ENABLE ROW LEVEL SECURITY;

-- service_role は全件アクセス可
CREATE POLICY "service_role_full_access_notifications" ON app_notifications
  FOR ALL USING (auth.role() = 'service_role');

-- ユーザーは自分宛 or 全体向けの通知を読める
CREATE POLICY "users_read_own_notifications" ON app_notifications
  FOR SELECT USING (
    auth.uid() = user_id OR user_id IS NULL
  );

-- ユーザーは自分の通知を既読に更新できる
CREATE POLICY "users_update_own_notifications" ON app_notifications
  FOR UPDATE USING (
    auth.uid() = user_id OR user_id IS NULL
  );

-- user_profiles に onboarding_completed カラムを追加 (存在しなければ)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'user_profiles' AND column_name = 'onboarding_completed'
  ) THEN
    ALTER TABLE user_profiles ADD COLUMN onboarding_completed jsonb DEFAULT '{}'::jsonb;
  END IF;
END
$$;

-- Session 425 実績シード
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  ('Notification Center Edge Function 追加', '通知センター API。アプリ内通知の作成・一覧・既読管理・全体通知/個別通知対応。7種類の通知カテゴリ', '2026-03-31'),
  ('Onboarding Flow Edge Function 追加', '新規ユーザーオンボーディング管理。6ステップの進捗追跡・自動判定 (プロフィール/ノート作成)・次ステップ提案', '2026-03-31'),
  ('growth-achievement-summary 修正', 'referrals テーブル参照を app_analytics の referral_completed イベントに修正', '2026-03-31'),
  ('ai-secretary 会話ログ記録修正', 'UPDATE+order+limit の不正なクエリを INSERT に修正', '2026-03-31')
ON CONFLICT DO NOTHING;
