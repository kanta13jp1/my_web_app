-- 刑務所モード: 借金完済まで生活を律する
CREATE TABLE IF NOT EXISTS prison_mode (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active boolean NOT NULL DEFAULT false,
  activated_at timestamptz,
  released_at timestamptz,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE prison_mode ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own prison mode"
  ON prison_mode FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 借金台帳
CREATE TABLE IF NOT EXISTS prison_debts (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  creditor_name text NOT NULL,
  original_amount int NOT NULL,
  remaining_amount int NOT NULL DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_prison_debts_user
  ON prison_debts (user_id);

ALTER TABLE prison_debts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own debts"
  ON prison_debts FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- 日課遵守ログ
CREATE TABLE IF NOT EXISTS prison_schedule_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  schedule_key text NOT NULL,
  completed_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz DEFAULT now(),
  UNIQUE (user_id, schedule_key, completed_date)
);

CREATE INDEX IF NOT EXISTS idx_prison_schedule_logs_user_date
  ON prison_schedule_logs (user_id, completed_date);

ALTER TABLE prison_schedule_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own schedule logs"
  ON prison_schedule_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
