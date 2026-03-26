-- 毎月の支払いリマインダー機能
-- auの支払い、家賃、サブスクなど定期支払いを管理

CREATE TABLE IF NOT EXISTS payment_reminders (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  title text NOT NULL,
  amount int,
  currency text NOT NULL DEFAULT 'JPY',
  payee text,
  payment_method text,
  due_day int NOT NULL CHECK (due_day BETWEEN 1 AND 31),
  recurrence text NOT NULL DEFAULT 'monthly'
    CHECK (recurrence IN ('monthly', 'yearly', 'weekly', 'once')),
  recurrence_month int CHECK (recurrence_month BETWEEN 1 AND 12),
  category text NOT NULL DEFAULT 'other',
  is_active boolean NOT NULL DEFAULT true,
  is_auto_pay boolean NOT NULL DEFAULT false,
  note text,
  last_paid_at timestamptz,
  next_due_date date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE payment_reminders IS '定期支払いリマインダー';
COMMENT ON COLUMN payment_reminders.due_day IS '毎月の支払日 (1-31)';
COMMENT ON COLUMN payment_reminders.recurrence IS 'monthly=毎月, yearly=年1回, weekly=毎週, once=一回のみ';
COMMENT ON COLUMN payment_reminders.recurrence_month IS '年1回の場合の月 (1-12)';
COMMENT ON COLUMN payment_reminders.category IS 'telecom, rent, utility, subscription, insurance, tax, loan, other';
COMMENT ON COLUMN payment_reminders.is_auto_pay IS '自動引落しの場合true (リマインドのみ)';
COMMENT ON COLUMN payment_reminders.payment_method IS '銀行振込, クレジットカード, コンビニ払い, 口座引落 等';

-- 支払い実績ログ
CREATE TABLE IF NOT EXISTS payment_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  reminder_id uuid REFERENCES payment_reminders(id) ON DELETE CASCADE,
  paid_at timestamptz NOT NULL DEFAULT now(),
  amount int,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE payment_logs IS '支払い実績ログ';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_payment_reminders_user
  ON payment_reminders (user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_payment_reminders_due
  ON payment_reminders (user_id, is_active, due_day);

CREATE INDEX IF NOT EXISTS idx_payment_logs_reminder
  ON payment_logs (reminder_id, paid_at DESC);

-- RLS
ALTER TABLE payment_reminders ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_payment_reminders"
  ON payment_reminders FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_own_payment_logs"
  ON payment_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "service_role_payment_reminders"
  ON payment_reminders FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "service_role_payment_logs"
  ON payment_logs FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
