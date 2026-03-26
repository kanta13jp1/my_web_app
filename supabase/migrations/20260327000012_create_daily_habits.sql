-- 毎日の定型タスク (習慣) リマインダー
-- マネーフォワード更新、財布残高入力、体重記録など毎日やるべきことを管理

CREATE TABLE IF NOT EXISTS daily_habits (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  title text NOT NULL,
  description text,
  icon_name text DEFAULT 'check_circle',
  color_hex text DEFAULT '#4338CA',
  remind_time time,
  is_active boolean NOT NULL DEFAULT true,
  streak int NOT NULL DEFAULT 0,
  best_streak int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE daily_habits IS '毎日の定型タスク (習慣)';
COMMENT ON COLUMN daily_habits.remind_time IS 'リマインド時刻 (例: 21:00)';
COMMENT ON COLUMN daily_habits.streak IS '現在の連続達成日数';
COMMENT ON COLUMN daily_habits.best_streak IS '過去最高の連続達成日数';

-- 日次完了ログ
CREATE TABLE IF NOT EXISTS daily_habit_logs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL,
  habit_id uuid REFERENCES daily_habits(id) ON DELETE CASCADE,
  completed_date date NOT NULL,
  completed_at timestamptz NOT NULL DEFAULT now(),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(habit_id, completed_date)
);

COMMENT ON TABLE daily_habit_logs IS '習慣の日次完了ログ';

-- インデックス
CREATE INDEX IF NOT EXISTS idx_daily_habits_user
  ON daily_habits (user_id, is_active);

CREATE INDEX IF NOT EXISTS idx_daily_habit_logs_habit_date
  ON daily_habit_logs (habit_id, completed_date DESC);

CREATE INDEX IF NOT EXISTS idx_daily_habit_logs_user_date
  ON daily_habit_logs (user_id, completed_date DESC);

-- RLS
ALTER TABLE daily_habits ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_habit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users_own_daily_habits"
  ON daily_habits FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "users_own_daily_habit_logs"
  ON daily_habit_logs FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "service_role_daily_habits"
  ON daily_habits FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "service_role_daily_habit_logs"
  ON daily_habit_logs FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
