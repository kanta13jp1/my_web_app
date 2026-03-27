-- 行動・発言振り返りログ
CREATE TABLE IF NOT EXISTS behavior_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('action', 'utterance')),
  content text NOT NULL,
  context text,
  regret_level int NOT NULL DEFAULT 0 CHECK (regret_level BETWEEN 0 AND 5),
  reflection text,
  ai_analysis text,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_behavior_log_user_date
  ON behavior_log (user_id, occurred_at DESC);

ALTER TABLE behavior_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own behavior log"
  ON behavior_log FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
