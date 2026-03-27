-- WIP制限: 消化してから次を食えシステム
CREATE TABLE IF NOT EXISTS wip_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category text NOT NULL,
  emoji text NOT NULL DEFAULT '📦',
  title text NOT NULL,
  note text,
  progress_percent int NOT NULL DEFAULT 0 CHECK (progress_percent BETWEEN 0 AND 100),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
  completed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wip_items_user_status
  ON wip_items (user_id, status);

ALTER TABLE wip_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own wip items"
  ON wip_items FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
