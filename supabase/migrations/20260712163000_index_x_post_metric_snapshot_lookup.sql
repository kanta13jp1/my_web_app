-- The X growth report normalizes impressions by post age. It reads metric
-- snapshots for up to 100 source logs, ordered by observation time. Without
-- this expression index, each page scans every x_post_metric_snapshot row and
-- production PostgREST cancels the statement before the weekly report can run.
CREATE INDEX IF NOT EXISTS idx_hub_data_x_metric_snapshot_log_user_created
  ON public.hub_data (
    (metadata->>'source_log_id'),
    (metadata->>'user_id'),
    created_at ASC
  )
  WHERE source = 'x_post_metric_snapshot';
