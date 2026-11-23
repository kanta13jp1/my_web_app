-- #2696: 競合他社発掘ワークフロー 0件アラート・詳細ログ保存テーブル (2026-11-24)

CREATE TABLE IF NOT EXISTS public.competitor_discovery_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  discovery_week text NOT NULL,
  run_id text,
  categories text[] NOT NULL DEFAULT '{}'::text[],
  queries_json jsonb NOT NULL DEFAULT '[]'::jsonb,
  total_candidates integer NOT NULL DEFAULT 0,
  staged_count integer NOT NULL DEFAULT 0,
  skip_count integer NOT NULL DEFAULT 0,
  error_count integer NOT NULL DEFAULT 0,
  error_logs jsonb NOT NULL DEFAULT '[]'::jsonb,
  zero_result_alert_triggered boolean NOT NULL DEFAULT false,
  alert_summary text,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.competitor_discovery_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated read competitor_discovery_logs"
  ON public.competitor_discovery_logs;
CREATE POLICY "Authenticated read competitor_discovery_logs"
  ON public.competitor_discovery_logs FOR SELECT
  TO authenticated USING (true);

DROP POLICY IF EXISTS "Service role write competitor_discovery_logs"
  ON public.competitor_discovery_logs;
CREATE POLICY "Service role write competitor_discovery_logs"
  ON public.competitor_discovery_logs FOR ALL
  TO service_role USING (true) WITH CHECK (true);

CREATE INDEX IF NOT EXISTS idx_competitor_discovery_logs_created_at
  ON public.competitor_discovery_logs (created_at DESC);

CREATE INDEX IF NOT EXISTS idx_competitor_discovery_logs_alert
  ON public.competitor_discovery_logs (zero_result_alert_triggered, created_at DESC);

COMMENT ON TABLE public.competitor_discovery_logs IS
  'competitor-discovery.yml の検索クエリ・応答抜粋・エラー詳細・0件アラート履歴を保持 (#2696)。';
