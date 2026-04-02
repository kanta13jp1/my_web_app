-- 決済ソース台帳テーブル
CREATE TABLE IF NOT EXISTS payment_sources (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  type text NOT NULL DEFAULT 'credit_card', -- credit_card | bank_account | e_wallet | crypto | other
  provider text, -- Visa, Mastercard, PayPay, etc.
  last_four text, -- 下4桁
  is_active boolean NOT NULL DEFAULT true,
  last_audited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_sources_user ON payment_sources(user_id);

ALTER TABLE payment_sources ENABLE ROW LEVEL SECURITY;

-- service_role は全件アクセス可
CREATE POLICY "service_role_full_access_payment_sources" ON payment_sources
  FOR ALL USING (auth.role() = 'service_role');

-- ユーザーは自分の決済ソースを読み書きできる
CREATE POLICY "users_manage_own_payment_sources" ON payment_sources
  FOR ALL USING (auth.uid() = user_id);

-- 初期シードデータ: デフォルトの決済ソース例（全ユーザー向け、user_id = null）
-- 実データはユーザーが登録する
