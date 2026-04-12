-- Add hub-compatible columns to app_analytics
-- Hub EFs (growth-hub, tools-hub, enterprise-hub, etc.) use app_analytics as a
-- generic CRUD store with source/metadata/id/created_at columns.
-- The existing app_analytics table (daily analytics with a 'date' column)
-- does not have these columns, causing all hub EF actions to return 500.

ALTER TABLE app_analytics
  ADD COLUMN IF NOT EXISTS id uuid DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS source text,
  ADD COLUMN IF NOT EXISTS metadata jsonb DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

-- Index for hub EF queries (filter by source, then metadata user_id)
CREATE INDEX IF NOT EXISTS idx_app_analytics_source
  ON app_analytics (source);

CREATE INDEX IF NOT EXISTS idx_app_analytics_metadata_gin
  ON app_analytics USING gin (metadata jsonb_path_ops);
