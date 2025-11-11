-- タイマー履歴テーブル
CREATE TABLE timers (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  note_id BIGINT REFERENCES notes(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT 'タイマー',
  duration_seconds INTEGER NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'paused', 'completed', 'stopped')),
  sound_notification BOOLEAN NOT NULL DEFAULT true,
  browser_notification BOOLEAN NOT NULL DEFAULT true,
  auto_save BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- インデックス
CREATE INDEX idx_timers_user_id ON timers(user_id);
CREATE INDEX idx_timers_note_id ON timers(note_id);
CREATE INDEX idx_timers_status ON timers(status);

-- RLSポリシー
ALTER TABLE timers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own timers"
  ON timers FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own timers"
  ON timers FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own timers"
  ON timers FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own timers"
  ON timers FOR DELETE
  USING (auth.uid() = user_id);

-- updated_at自動更新用トリガー
CREATE OR REPLACE FUNCTION update_timers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_timers_updated_at
  BEFORE UPDATE ON timers
  FOR EACH ROW
  EXECUTE FUNCTION update_timers_updated_at();
