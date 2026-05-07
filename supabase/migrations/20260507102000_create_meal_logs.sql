CREATE TABLE IF NOT EXISTS meal_logs (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  meal_type TEXT NOT NULL CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack')),
  menu_name TEXT NOT NULL,
  store_name TEXT,
  kcal INT,
  protein_g NUMERIC(6, 2),
  fat_g NUMERIC(6, 2),
  carb_g NUMERIC(6, 2),
  vegetables_note TEXT,
  salt_note TEXT,
  logged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS meal_logs_user_id_logged_at_idx
  ON meal_logs (user_id, logged_at DESC);

ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS meal_logs_select_own ON meal_logs;
DROP POLICY IF EXISTS meal_logs_insert_own ON meal_logs;
DROP POLICY IF EXISTS meal_logs_update_own ON meal_logs;
DROP POLICY IF EXISTS meal_logs_delete_own ON meal_logs;

CREATE POLICY meal_logs_select_own ON meal_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY meal_logs_insert_own ON meal_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY meal_logs_update_own ON meal_logs FOR UPDATE
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE POLICY meal_logs_delete_own ON meal_logs FOR DELETE
  USING (auth.uid() = user_id);
