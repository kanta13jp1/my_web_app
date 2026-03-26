-- メールサブスク管理テーブル
-- 不要なメルマガ・通知を特定し、解除を管理する

CREATE TABLE IF NOT EXISTS email_subscriptions (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  email_account_id uuid REFERENCES email_accounts(id) ON DELETE CASCADE,
  sender_name text NOT NULL,
  sender_email text,
  category text NOT NULL DEFAULT 'newsletter'
    CHECK (category IN (
      'newsletter', 'promotion', 'notification',
      'subscription', 'social', 'other'
    )),
  action text NOT NULL DEFAULT 'keep'
    CHECK (action IN ('keep', 'unsubscribe', 'filter', 'delete')),
  is_processed boolean NOT NULL DEFAULT false,
  processed_at timestamptz,
  frequency text,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE email_subscriptions IS '受信メールのサブスク・メルマガ管理';
COMMENT ON COLUMN email_subscriptions.action IS 'keep=維持, unsubscribe=解除, filter=フィルタ設定, delete=削除';
COMMENT ON COLUMN email_subscriptions.frequency IS '受信頻度メモ (毎日, 週1, 月1 等)';

-- メール整理ルーチンのチェックリストテンプレート
CREATE TABLE IF NOT EXISTS email_cleanup_routines (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  step_order int NOT NULL,
  title text NOT NULL,
  description text,
  is_completed boolean NOT NULL DEFAULT false,
  completed_date date,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE email_cleanup_routines IS 'メール整理ルーチンのチェックリスト';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_email_subscriptions_user
  ON email_subscriptions (user_id, is_processed);

CREATE INDEX IF NOT EXISTS idx_email_cleanup_routines_user
  ON email_cleanup_routines (user_id, step_order);

-- RLS
ALTER TABLE email_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_cleanup_routines ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_email_subscriptions"
  ON email_subscriptions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_own_email_cleanup_routines"
  ON email_cleanup_routines FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "service_role_email_subscriptions"
  ON email_subscriptions FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "service_role_email_cleanup_routines"
  ON email_cleanup_routines FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
