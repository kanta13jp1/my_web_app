CREATE TABLE IF NOT EXISTS ai_task_routing_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  task text NOT NULL,
  provider text NOT NULL,
  model text,
  is_enabled boolean NOT NULL DEFAULT true,
  source text NOT NULL DEFAULT 'manual',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ai_task_routing_preferences_task_not_blank
    CHECK (length(btrim(task)) > 0),
  CONSTRAINT ai_task_routing_preferences_provider_not_blank
    CHECK (length(btrim(provider)) > 0),
  CONSTRAINT ai_task_routing_preferences_source_allowed
    CHECK (source IN ('manual', 'recommendation', 'migration'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ai_task_routing_preferences_user_task_uidx
  ON ai_task_routing_preferences (user_id, task);

CREATE INDEX IF NOT EXISTS ai_task_routing_preferences_user_enabled_idx
  ON ai_task_routing_preferences (user_id, is_enabled, updated_at DESC);

ALTER TABLE ai_task_routing_preferences ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_task_routing_preferences_select_own
  ON ai_task_routing_preferences;
CREATE POLICY ai_task_routing_preferences_select_own
  ON ai_task_routing_preferences
  FOR SELECT
  USING (auth.uid() = user_id OR auth.role() = 'service_role');

DROP POLICY IF EXISTS ai_task_routing_preferences_write_own
  ON ai_task_routing_preferences;
CREATE POLICY ai_task_routing_preferences_write_own
  ON ai_task_routing_preferences
  FOR ALL
  USING (auth.uid() = user_id OR auth.role() = 'service_role')
  WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

COMMENT ON TABLE ai_task_routing_preferences IS
  'Manual per-task AI router defaults selected from the cost-performance dashboard.';
COMMENT ON COLUMN ai_task_routing_preferences.task IS
  'Normalized task bucket such as summary, translation, coding, analysis, writing, or chat.';
