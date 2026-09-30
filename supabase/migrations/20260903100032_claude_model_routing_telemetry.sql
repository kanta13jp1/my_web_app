-- Issue #2922: make Claude difficulty routing observable per model.
-- Existing rows remain valid and nullable during staged Edge Function rollout.

ALTER TABLE public.ai_hub_chat_logs
  ADD COLUMN IF NOT EXISTS routing_effort text,
  ADD COLUMN IF NOT EXISTS routing_source text,
  ADD COLUMN IF NOT EXISTS input_tokens integer,
  ADD COLUMN IF NOT EXISTS output_tokens integer;

DO $constraints$
BEGIN
  ALTER TABLE public.ai_hub_chat_logs
    ADD CONSTRAINT ai_hub_chat_logs_routing_effort_check
    CHECK (
      routing_effort IS NULL
      OR routing_effort IN ('low', 'medium', 'high', 'xhigh')
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

DO $constraints$
BEGIN
  ALTER TABLE public.ai_hub_chat_logs
    ADD CONSTRAINT ai_hub_chat_logs_routing_source_check
    CHECK (routing_source IS NULL OR routing_source IN ('db', 'local'));
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

DO $constraints$
BEGIN
  ALTER TABLE public.ai_hub_chat_logs
    ADD CONSTRAINT ai_hub_chat_logs_input_tokens_check
    CHECK (input_tokens IS NULL OR input_tokens >= 0);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

DO $constraints$
BEGIN
  ALTER TABLE public.ai_hub_chat_logs
    ADD CONSTRAINT ai_hub_chat_logs_output_tokens_check
    CHECK (output_tokens IS NULL OR output_tokens >= 0);
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_model_created_at_idx
  ON public.ai_hub_chat_logs(model, created_at DESC)
  WHERE model IS NOT NULL;

CREATE OR REPLACE VIEW public.claude_model_usage_daily
WITH (security_invoker = true)
AS
SELECT
  date_trunc('day', created_at) AS usage_day,
  model,
  routing_effort,
  routing_source,
  count(*) AS api_request_count,
  sum(COALESCE(input_tokens, 0)) AS input_tokens,
  sum(COALESCE(output_tokens, 0)) AS output_tokens,
  sum(COALESCE(estimated_cost_usd, 0)) AS estimated_cost_usd
FROM public.ai_hub_chat_logs
WHERE provider = 'anthropic'
  AND success
  AND model IS NOT NULL
GROUP BY
  date_trunc('day', created_at),
  model,
  routing_effort,
  routing_source;

REVOKE ALL ON TABLE public.claude_model_usage_daily
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.claude_model_usage_daily TO service_role;

COMMENT ON COLUMN public.ai_hub_chat_logs.routing_effort IS
  'Difficulty selected by effort_router for the completed provider request.';
COMMENT ON COLUMN public.ai_hub_chat_logs.routing_source IS
  'Whether the effort decision came from effort_config (db) or the local fallback matrix.';
COMMENT ON COLUMN public.ai_hub_chat_logs.input_tokens IS
  'Provider-reported input tokens when available; otherwise the bounded character estimate.';
COMMENT ON COLUMN public.ai_hub_chat_logs.output_tokens IS
  'Provider-reported output tokens when available; otherwise the bounded character estimate.';
COMMENT ON VIEW public.claude_model_usage_daily IS
  'Service-role-only daily Claude request, token, and estimated-cost totals by model and routing decision.';
