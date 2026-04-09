-- focus_sessions: ポモドーロ集中セッション記録テーブル
-- focus-timer Edge Function が利用

CREATE TABLE IF NOT EXISTS focus_sessions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task_label       TEXT NOT NULL DEFAULT '集中作業',
  duration_minutes INTEGER NOT NULL DEFAULT 25,
  status           TEXT NOT NULL DEFAULT 'active'
                   CHECK (status IN ('active', 'completed', 'cancelled')),
  started_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_id
  ON focus_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_focus_sessions_started_at
  ON focus_sessions(started_at DESC);

-- RLS
ALTER TABLE focus_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "focus_sessions: users manage own"
  ON focus_sessions
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
