-- Issue #5102: Exclude client-side input guardrail blocks (HTTP 422) from provider_health_view error metrics.
-- Upstream provider failures (e.g., 400/402/429/5xx) remain counted as provider errors.

CREATE OR REPLACE VIEW public.provider_health_view
WITH (security_invoker = true) AS
WITH recent AS (
  SELECT
    ai_hub_chat_logs.provider,
    ai_hub_chat_logs.success,
    ai_hub_chat_logs.latency_ms,
    ai_hub_chat_logs.error_message,
    ai_hub_chat_logs.created_at
  FROM public.ai_hub_chat_logs
  WHERE ai_hub_chat_logs.created_at >= (now() - '24:00:00'::interval)
    AND COALESCE(ai_hub_chat_logs.status_code, 0) <> 422
    AND COALESCE(ai_hub_chat_logs.error_message, '') NOT LIKE 'guardrail_blocked%'
)
SELECT
  provider,
  count(*) AS total_requests,
  count(*) FILTER (WHERE success) AS success_count,
  count(*) FILTER (WHERE NOT success) AS error_count,
  round(
    100.0 * count(*) FILTER (WHERE success)::numeric / NULLIF(count(*), 0)::numeric,
    2
  ) AS success_rate_pct,
  percentile_cont(0.50::double precision) WITHIN GROUP (ORDER BY (latency_ms::double precision)) AS p50_latency_ms,
  percentile_cont(0.95::double precision) WITHIN GROUP (ORDER BY (latency_ms::double precision)) AS p95_latency_ms,
  max(latency_ms) AS max_latency_ms,
  max(created_at) AS last_seen_at,
  (
    100.0 * count(*) FILTER (WHERE NOT success AND created_at >= (now() - '01:00:00'::interval))::numeric
    / NULLIF(count(*) FILTER (WHERE created_at >= (now() - '01:00:00'::interval)), 0)::numeric
  ) > 50::numeric AS is_flaky_now
FROM recent
GROUP BY provider
ORDER BY (count(*)) DESC;

COMMENT ON VIEW public.provider_health_view IS '過去24時間のプロバイダー別ヘルス（HTTP 422 入力ガードレール拒否はプロバイダ障害から除外）。p50/p95/error_rate/flaky 検出。AI Observability ページ用';
