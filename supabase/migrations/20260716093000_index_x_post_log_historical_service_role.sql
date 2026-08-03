-- Keep the service-role X performance query on an ordered partial index.
--
-- The existing index is (learning_cohort, user_id, created_at). Cron requests
-- intentionally do not constrain user_id, so PostgreSQL cannot use that index
-- to satisfy ORDER BY created_at DESC. Historical benchmark rows are old and
-- sparse, which otherwise makes the query scan recent x_post_log rows until it
-- reaches statement_timeout.
CREATE INDEX IF NOT EXISTS idx_hub_data_x_post_log_historical_created
  ON public.hub_data (created_at DESC)
  WHERE source = 'x_post_log'
    AND metadata->>'learning_cohort' = 'historical_benchmark';
