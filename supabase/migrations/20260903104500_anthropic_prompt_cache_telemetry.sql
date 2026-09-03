-- Issue #2923: persist Anthropic prompt-cache reads and writes.

ALTER TABLE public.ai_hub_chat_logs
  ADD COLUMN IF NOT EXISTS cache_read_input_tokens integer,
  ADD COLUMN IF NOT EXISTS cache_creation_input_tokens integer;

DO $constraints$
BEGIN
  ALTER TABLE public.ai_hub_chat_logs
    ADD CONSTRAINT ai_hub_chat_logs_cache_read_input_tokens_check
    CHECK (
      cache_read_input_tokens IS NULL
      OR cache_read_input_tokens >= 0
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

DO $constraints$
BEGIN
  ALTER TABLE public.ai_hub_chat_logs
    ADD CONSTRAINT ai_hub_chat_logs_cache_creation_input_tokens_check
    CHECK (
      cache_creation_input_tokens IS NULL
      OR cache_creation_input_tokens >= 0
    );
EXCEPTION WHEN duplicate_object THEN
  NULL;
END;
$constraints$;

CREATE OR REPLACE VIEW public.anthropic_prompt_cache_usage_daily
WITH (security_invoker = true)
AS
SELECT
  date_trunc('day', created_at) AS usage_day,
  model,
  count(*) AS api_request_count,
  count(*) FILTER (
    WHERE COALESCE(cache_read_input_tokens, 0) > 0
  ) AS cache_hit_request_count,
  round(
    100.0 * count(*) FILTER (
      WHERE COALESCE(cache_read_input_tokens, 0) > 0
    ) / NULLIF(count(*), 0),
    2
  ) AS cache_hit_rate_pct,
  sum(COALESCE(input_tokens, 0)) AS uncached_input_tokens,
  sum(COALESCE(cache_read_input_tokens, 0)) AS cache_read_input_tokens,
  sum(COALESCE(cache_creation_input_tokens, 0))
    AS cache_creation_input_tokens,
  sum(COALESCE(estimated_cost_usd, 0)) AS estimated_cost_usd
FROM public.ai_hub_chat_logs
WHERE provider = 'anthropic'
  AND success
  AND model IS NOT NULL
GROUP BY
  date_trunc('day', created_at),
  model;

REVOKE ALL ON TABLE public.anthropic_prompt_cache_usage_daily
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.anthropic_prompt_cache_usage_daily
  TO service_role;

COMMENT ON COLUMN public.ai_hub_chat_logs.cache_read_input_tokens IS
  'Anthropic usage.cache_read_input_tokens: prompt-prefix tokens reused from cache.';
COMMENT ON COLUMN public.ai_hub_chat_logs.cache_creation_input_tokens IS
  'Anthropic usage.cache_creation_input_tokens: prompt-prefix tokens written to cache.';
COMMENT ON VIEW public.anthropic_prompt_cache_usage_daily IS
  'Service-role-only daily Anthropic prompt-cache hit, token, and cost totals.';
