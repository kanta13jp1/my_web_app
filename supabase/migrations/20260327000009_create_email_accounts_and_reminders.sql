-- メール整理リマインダー機能
-- ユーザーが管理対象のメールアカウントを登録し、
-- 定期的にメール整理をリマインドする

-- 1. メールアカウント管理テーブル
CREATE TABLE IF NOT EXISTS email_accounts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  email_address text NOT NULL,
  provider text NOT NULL DEFAULT 'other',
  label text,
  is_active boolean NOT NULL DEFAULT true,
  last_cleaned_at timestamptz,
  clean_interval_days int NOT NULL DEFAULT 7,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, email_address)
);

COMMENT ON TABLE email_accounts IS 'ユーザーが管理するメールアカウント一覧';
COMMENT ON COLUMN email_accounts.provider IS 'gmail, outlook, yahoo, icloud, other';
COMMENT ON COLUMN email_accounts.label IS 'ユーザーが付ける表示名 (例: 仕事用, 個人用)';
COMMENT ON COLUMN email_accounts.last_cleaned_at IS '最後にメール整理を実施した日時';
COMMENT ON COLUMN email_accounts.clean_interval_days IS 'リマインド間隔 (日)';

-- 2. メール整理ログテーブル
CREATE TABLE IF NOT EXISTS email_clean_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  email_account_id uuid REFERENCES email_accounts(id) ON DELETE CASCADE,
  cleaned_at timestamptz NOT NULL DEFAULT now(),
  deleted_count int DEFAULT 0,
  archived_count int DEFAULT 0,
  unsubscribed_count int DEFAULT 0,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE email_clean_logs IS 'メール整理の実施ログ';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_email_accounts_user
  ON email_accounts (user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_email_accounts_reminder
  ON email_accounts (user_id, is_active, last_cleaned_at);

CREATE INDEX IF NOT EXISTS idx_email_clean_logs_account
  ON email_clean_logs (email_account_id, cleaned_at DESC);

-- RLS
ALTER TABLE email_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_clean_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_email_accounts"
  ON email_accounts FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_own_email_clean_logs"
  ON email_clean_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "service_role_email_accounts"
  ON email_accounts FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "service_role_email_clean_logs"
  ON email_clean_logs FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
