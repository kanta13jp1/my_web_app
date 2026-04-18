-- PS版#117: ai-hub provider.chat_auto Tier routing — chat log table
CREATE TABLE IF NOT EXISTS ai_hub_chat_logs (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider    text NOT NULL,
  tier        text NOT NULL,
  success     boolean NOT NULL DEFAULT true,
  model       text,
  estimated_cost_usd numeric(12, 8),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_created_at_idx ON ai_hub_chat_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_provider_idx ON ai_hub_chat_logs (provider);
CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_tier_idx ON ai_hub_chat_logs (tier);

ALTER TABLE ai_hub_chat_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service role full access" ON ai_hub_chat_logs
  FOR ALL USING (true) WITH CHECK (true);
