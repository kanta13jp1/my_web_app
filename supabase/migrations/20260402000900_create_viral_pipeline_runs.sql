-- viral_pipeline_runs: バイラル広告パイプラインの実行ログ
-- viral-growth-pipeline Edge Function が使用

CREATE TABLE IF NOT EXISTS viral_pipeline_runs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  template text NOT NULL DEFAULT 'growth_stats',
  tweet_text text,
  tweet_id text,
  media_id text,
  dry_run boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'success'
    CHECK (status IN ('success', 'error', 'dry_run')),
  error_message text,
  stats_snapshot jsonb,
  svg_content text,
  impressions integer,
  clicks integer,
  new_follows integer,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Index for dashboard queries
CREATE INDEX IF NOT EXISTS idx_viral_pipeline_runs_created_at
  ON viral_pipeline_runs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_viral_pipeline_runs_status
  ON viral_pipeline_runs (status);

-- RLS
ALTER TABLE viral_pipeline_runs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role_all_viral_pipeline_runs" ON viral_pipeline_runs;
CREATE POLICY "service_role_all_viral_pipeline_runs"
  ON viral_pipeline_runs FOR ALL
  USING (auth.role() = 'service_role');

DROP POLICY IF EXISTS "admin_read_viral_pipeline_runs" ON viral_pipeline_runs;
CREATE POLICY "admin_read_viral_pipeline_runs"
  ON viral_pipeline_runs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles
      WHERE user_profiles.id = auth.uid()
        AND user_profiles.is_admin = true
    )
  );

COMMENT ON TABLE viral_pipeline_runs IS
  'バイラル広告パイプラインの実行ログ。viral-growth-pipeline Edge Function が書き込み、管理者ダッシュボードで表示。';
