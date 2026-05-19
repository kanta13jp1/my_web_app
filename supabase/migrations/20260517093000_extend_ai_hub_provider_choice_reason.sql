-- Issue #2521: persist asset-management AI provider routing evidence.
-- Provider choice reason is intentionally short, sanitized, and nullable so
-- existing ai_hub_chat_logs inserts keep working during staged deploys.

ALTER TABLE ai_hub_chat_logs
  ADD COLUMN IF NOT EXISTS provider_choice_reason text,
  ADD COLUMN IF NOT EXISTS routing_use_case text;

CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_routing_use_case_idx
  ON ai_hub_chat_logs (routing_use_case, created_at DESC)
  WHERE routing_use_case IS NOT NULL;

COMMENT ON COLUMN ai_hub_chat_logs.provider_choice_reason IS
  'Short sanitized reason for model/provider routing; must not include PII, raw balances, or user IDs.';

COMMENT ON COLUMN ai_hub_chat_logs.routing_use_case IS
  'Feature-level routing use case such as asset summary, risk explanation, developer suggestion, or reconciliation help.';
