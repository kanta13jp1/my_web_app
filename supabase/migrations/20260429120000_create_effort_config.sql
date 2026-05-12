-- PLATFORM #7: effort_router configuration.

CREATE TABLE IF NOT EXISTS effort_config (
  action text PRIMARY KEY,
  default_effort text NOT NULL CHECK (default_effort IN ('low', 'medium', 'high', 'xhigh')),
  rationale text NOT NULL,
  model_override text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE effort_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS effort_config_service_role ON effort_config;
CREATE POLICY effort_config_service_role ON effort_config
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP TRIGGER IF EXISTS update_effort_config_updated_at ON effort_config;
CREATE TRIGGER update_effort_config_updated_at
  BEFORE UPDATE ON effort_config
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

INSERT INTO effort_config (action, default_effort, rationale) VALUES
  ('ai.assistant.chat', 'low', 'Daily assistant chat favors latency and low cost.'),
  ('ai.university.quiz_grade', 'low', 'Deterministic quiz grading only needs a lightweight model.'),
  ('ai.competitor.monitor', 'medium', 'Monitoring requires short summarization and classification.'),
  ('ai.video.caption', 'medium', 'Caption generation is structured text with moderate context.'),
  ('ai.daily.judgment', 'high', 'Daily judgment combines multiple personal signals.'),
  ('ai.cross_instance.routing', 'high', 'Cross-instance routing requires trade-off analysis.'),
  ('ai.horse_racing.predict', 'xhigh', 'Horse racing prediction uses many interacting factors.'),
  ('ai.notebooklm.distill', 'xhigh', 'Axis distillation needs deep synthesis across prior decisions.'),
  ('provider.chat_auto', 'medium', 'Automatic provider routing is general purpose chat.'),
  ('edge_llm.invoke', 'medium', 'Generic EF LLM invoke balances latency and quality by default.'),
  ('memory.search', 'low', 'BM25 and vector retrieval should stay fast.'),
  ('memory.rank', 'low', 'Reranking is capped to a small candidate set.'),
  ('memory.lint', 'medium', 'Memory linting may need semantic judgment.')
ON CONFLICT (action) DO UPDATE SET
  default_effort = EXCLUDED.default_effort,
  rationale = EXCLUDED.rationale,
  updated_at = now();

COMMENT ON TABLE effort_config IS 'PLATFORM #7 effort router matrix. Maps EF/GHA actions to low/medium/high/xhigh reasoning effort.';
