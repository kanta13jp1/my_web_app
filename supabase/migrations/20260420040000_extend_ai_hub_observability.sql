-- AI Observability Extension
-- NotebookLM "TraceHawk vs Datadog: AI Agent Observability in 2026" (f56cc07c) を統合
-- (Win版#131 セッション 4 / 2026-04-20)
--
-- 既存 ai_hub_chat_logs (PS版#117) を拡張:
--   - latency_ms / trace_id / session_id / error_message / status_code / user_id
--   - input_chars / output_chars (token cost 推定の精度向上)
-- + SQL views: provider_health_view / provider_heatmap_view / session_trace_view
--
-- 既存 Rule 23 (AI-DEV 7原則) との関係:
--   - #3 trace_id+5秒検出 → 本拡張で実データ蓄積 + ダッシュボード化
--   - #4 cost circuit breaker → 既存 ai_quota_usage を補完 (より細粒度)

-- ============================================================
-- 1. ai_hub_chat_logs 拡張 (既存テーブルに ALTER ADD)
-- ============================================================
ALTER TABLE ai_hub_chat_logs
  ADD COLUMN IF NOT EXISTS latency_ms     int,
  ADD COLUMN IF NOT EXISTS trace_id       text,
  ADD COLUMN IF NOT EXISTS session_id     text,
  ADD COLUMN IF NOT EXISTS user_id        uuid,
  ADD COLUMN IF NOT EXISTS error_message  text,
  ADD COLUMN IF NOT EXISTS status_code    int,
  ADD COLUMN IF NOT EXISTS input_chars    int,
  ADD COLUMN IF NOT EXISTS output_chars   int,
  ADD COLUMN IF NOT EXISTS action         text;

-- 既存 INSERT が壊れないように全て NULL 許容

-- 観測クエリの最適化
CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_trace_id_idx
  ON ai_hub_chat_logs (trace_id) WHERE trace_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_session_id_idx
  ON ai_hub_chat_logs (session_id) WHERE session_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_user_id_idx
  ON ai_hub_chat_logs (user_id, created_at DESC) WHERE user_id IS NOT NULL;

-- p50/p95 計算用 (provider × created_at)
-- date_trunc('hour', timestamptz) は STABLE で index 化不可 → created_at で代替。
-- heatmap_view の GROUP BY date_trunc は range scan で効く。
CREATE INDEX IF NOT EXISTS ai_hub_chat_logs_provider_created_at_idx
  ON ai_hub_chat_logs (provider, created_at DESC);

COMMENT ON COLUMN ai_hub_chat_logs.latency_ms IS 'リクエストの応答時間 (ms)。p50/p95 集計に使用';
COMMENT ON COLUMN ai_hub_chat_logs.trace_id   IS '分散トレース ID。LLM ↔ DB ↔ EF を跨いだ relate に使用';
COMMENT ON COLUMN ai_hub_chat_logs.session_id IS 'ユーザーセッション ID。ステップバイステップ replay 用';
COMMENT ON COLUMN ai_hub_chat_logs.error_message IS 'エラー時の生メッセージ。flaky provider 検出用';

-- ============================================================
-- 2. provider_health_view: 過去 24h のプロバイダー別ヘルス
-- ============================================================
CREATE OR REPLACE VIEW provider_health_view AS
WITH recent AS (
  SELECT
    provider,
    success,
    latency_ms,
    error_message,
    created_at
  FROM ai_hub_chat_logs
  WHERE created_at >= now() - interval '24 hours'
)
SELECT
  provider,
  COUNT(*)                                                       AS total_requests,
  COUNT(*) FILTER (WHERE success)                                AS success_count,
  COUNT(*) FILTER (WHERE NOT success)                            AS error_count,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE success) / NULLIF(COUNT(*), 0),
    2
  )                                                              AS success_rate_pct,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY latency_ms)       AS p50_latency_ms,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms)       AS p95_latency_ms,
  MAX(latency_ms)                                                AS max_latency_ms,
  MAX(created_at)                                                AS last_seen_at,
  -- 直近 1h で 50% 以上失敗 = flaky 警告
  (
    100.0 * COUNT(*) FILTER (WHERE NOT success AND created_at >= now() - interval '1 hour')
    / NULLIF(COUNT(*) FILTER (WHERE created_at >= now() - interval '1 hour'), 0)
  ) > 50                                                         AS is_flaky_now
FROM recent
GROUP BY provider
ORDER BY total_requests DESC;

COMMENT ON VIEW provider_health_view IS '過去24時間のプロバイダー別ヘルス。p50/p95/error_rate/flaky 検出。AI Observability ページ用';

-- ============================================================
-- 3. provider_heatmap_view: 時間帯 × プロバイダー アクセス頻度
-- ============================================================
CREATE OR REPLACE VIEW provider_heatmap_view AS
SELECT
  provider,
  date_trunc('hour', created_at) AS hour_bucket,
  EXTRACT(HOUR FROM created_at)  AS hour_of_day,
  EXTRACT(DOW FROM created_at)   AS day_of_week,
  COUNT(*)                       AS request_count,
  ROUND(AVG(latency_ms))         AS avg_latency_ms,
  COUNT(*) FILTER (WHERE NOT success) AS error_count
FROM ai_hub_chat_logs
WHERE created_at >= now() - interval '7 days'
GROUP BY provider, hour_bucket, hour_of_day, day_of_week
ORDER BY hour_bucket DESC;

COMMENT ON VIEW provider_heatmap_view IS '過去7日のプロバイダー × 時間帯 アクセス頻度。リソース最適化判断材料';

-- ============================================================
-- 4. session_trace_view: セッション横断のトレース連結
-- ============================================================
CREATE OR REPLACE VIEW session_trace_view AS
SELECT
  session_id,
  user_id,
  COUNT(*)                          AS step_count,
  COUNT(*) FILTER (WHERE NOT success) AS error_step_count,
  SUM(latency_ms)                   AS total_latency_ms,
  SUM(estimated_cost_usd)           AS total_cost_usd,
  ARRAY_AGG(provider ORDER BY created_at) AS provider_chain,
  ARRAY_AGG(action ORDER BY created_at)   AS action_chain,
  MIN(created_at)                   AS started_at,
  MAX(created_at)                   AS ended_at,
  EXTRACT(EPOCH FROM MAX(created_at) - MIN(created_at)) AS duration_sec
FROM ai_hub_chat_logs
WHERE session_id IS NOT NULL
  AND created_at >= now() - interval '7 days'
GROUP BY session_id, user_id
ORDER BY started_at DESC;

COMMENT ON VIEW session_trace_view IS '直近7日のセッション一覧。step_count/total_cost/provider_chain で重要セッション特定';

-- ============================================================
-- 5. development_achievements への記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI Observability — プロバイダーヘルスダッシュボード + ヒートマップ + セッショントレース',
  'NotebookLM "TraceHawk vs Datadog" (f56cc07c) を統合。ai_hub_chat_logs を latency_ms/trace_id/session_id/error_message/status_code/input_chars/output_chars/action で拡張。3 SQL views (provider_health_view/provider_heatmap_view/session_trace_view) で p50/p95・flaky 検出・ヒートマップ・セッション連結を集計。Win版#131 part 4。',
  '2026-04-20'
)
ON CONFLICT DO NOTHING;
