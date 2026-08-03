-- X 週次実測レポート (growth-hub x.growth_data_report) の statement timeout 修正。
--
-- buildXPerformanceContext は x_post_log を 2 通りで読む:
--   1. listXPostLogs             : source='x_post_log' ORDER BY created_at DESC LIMIT N
--   2. listXHistoricalBenchmarkLogs: source='x_post_log'
--       AND metadata->>'learning_cohort'='historical_benchmark'
--       ORDER BY created_at DESC LIMIT N
--
-- hub_data には単列 index (source / created_at) しか無いため、(2) は
-- created_at 降順に x_post_log 行を全走査しつつ稀な旧 benchmark 行を探し、
-- 本番 PostgREST が statement timeout でキャンセルしていた
-- (2026-07-12/07-13 の X Growth Data Report Post cron が HTTP 500)。
-- #4016 は x_post_metric_snapshot 側のみ index 化しており本経路は未修正だった。
--
-- source='x_post_log' に限定した partial index で両クエリを index scan 化する。

-- listXPostLogs 用: x_post_log を created_at 降順で先頭 N 件。
CREATE INDEX IF NOT EXISTS idx_hub_data_x_post_log_created
  ON public.hub_data (created_at DESC)
  WHERE source = 'x_post_log';

-- listXHistoricalBenchmarkLogs 用: learning_cohort で直接ジャンプ + created_at 降順。
-- user_id を含め service_role (cron) 経路と user 絞込み経路の双方を index scan 化する。
CREATE INDEX IF NOT EXISTS idx_hub_data_x_post_log_cohort_created
  ON public.hub_data (
    (metadata->>'learning_cohort'),
    (metadata->>'user_id'),
    created_at DESC
  )
  WHERE source = 'x_post_log';
