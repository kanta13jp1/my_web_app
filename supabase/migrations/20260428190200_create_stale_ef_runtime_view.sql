-- Runtime stale Edge Function detection support.
--
-- The file-based audit in scripts/audit_hub_migration_completeness.py catches
-- stale references in the repository. These tables add the database side needed
-- to catch production/runtime calls to functions that are no longer in the
-- deploy-prod.yml allowlist.

CREATE TABLE IF NOT EXISTS public.deploy_prod_function_list (
  function_name text PRIMARY KEY,
  source text NOT NULL DEFAULT 'deploy-prod.yml',
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  synced_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS deploy_prod_function_list_active_idx
  ON public.deploy_prod_function_list (is_active, function_name);

ALTER TABLE public.deploy_prod_function_list ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role write deploy_prod_function_list"
  ON public.deploy_prod_function_list;
CREATE POLICY "service_role write deploy_prod_function_list"
  ON public.deploy_prod_function_list
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "authenticated read deploy_prod_function_list"
  ON public.deploy_prod_function_list;
CREATE POLICY "authenticated read deploy_prod_function_list"
  ON public.deploy_prod_function_list
  FOR SELECT
  USING (auth.role() = 'authenticated');

COMMENT ON TABLE public.deploy_prod_function_list IS
  'Canonical Edge Function deployment allowlist mirrored from .github/workflows/deploy-prod.yml.';
COMMENT ON COLUMN public.deploy_prod_function_list.function_name IS
  'Supabase Edge Function slug, e.g. tools-hub.';

INSERT INTO public.deploy_prod_function_list (function_name, notes)
VALUES
  ('get-home-dashboard', 'standalone deploy-prod.yml allowlist'),
  ('ai-assistant', 'standalone deploy-prod.yml allowlist'),
  ('growth-weekly-digest', 'standalone deploy-prod.yml allowlist'),
  ('guitar-recording-studio', 'standalone deploy-prod.yml allowlist'),
  ('core-hub', 'macro hub deploy-prod.yml allowlist'),
  ('growth-hub', 'macro hub deploy-prod.yml allowlist'),
  ('ai-hub', 'macro hub deploy-prod.yml allowlist'),
  ('admin-hub', 'macro hub deploy-prod.yml allowlist'),
  ('app-hub', 'macro hub deploy-prod.yml allowlist'),
  ('schedule-hub', 'macro hub deploy-prod.yml allowlist'),
  ('tools-hub', 'mega hub deploy-prod.yml allowlist'),
  ('media-hub', 'mega hub deploy-prod.yml allowlist'),
  ('enterprise-hub', 'mega hub deploy-prod.yml allowlist'),
  ('social-commerce-hub', 'mega hub deploy-prod.yml allowlist'),
  ('lifestyle-hub', 'mega hub deploy-prod.yml allowlist'),
  ('local-election-intelligence', 'mega hub deploy-prod.yml allowlist'),
  ('health-check', 'public health-check deploy-prod.yml allowlist')
ON CONFLICT (function_name) DO UPDATE
SET
  source = EXCLUDED.source,
  is_active = true,
  notes = EXCLUDED.notes,
  synced_at = now();

CREATE TABLE IF NOT EXISTS public.edge_function_runtime_invocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  function_name text NOT NULL,
  request_path text,
  response_status smallint,
  source text NOT NULL DEFAULT 'runtime',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  invoked_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS edge_function_runtime_invocations_function_idx
  ON public.edge_function_runtime_invocations (function_name, invoked_at DESC);

CREATE INDEX IF NOT EXISTS edge_function_runtime_invocations_recent_idx
  ON public.edge_function_runtime_invocations (invoked_at DESC);

ALTER TABLE public.edge_function_runtime_invocations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "service_role write edge_function_runtime_invocations"
  ON public.edge_function_runtime_invocations;
CREATE POLICY "service_role write edge_function_runtime_invocations"
  ON public.edge_function_runtime_invocations
  FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

DROP POLICY IF EXISTS "authenticated read edge_function_runtime_invocations"
  ON public.edge_function_runtime_invocations;

COMMENT ON TABLE public.edge_function_runtime_invocations IS
  'Runtime Edge Function call observations. Ingest from logs, hub middleware, or scheduled probes.';
COMMENT ON COLUMN public.edge_function_runtime_invocations.function_name IS
  'Supabase Edge Function slug parsed from /functions/v1/<function_name>.';

CREATE OR REPLACE VIEW public.stale_ef_runtime_invocations
WITH (security_invoker = true) AS
WITH recent AS (
  SELECT
    inv.function_name,
    count(*) AS invocation_count,
    max(inv.invoked_at) AS last_invoked_at,
    max(inv.response_status) FILTER (WHERE inv.invoked_at = latest.latest_invoked_at) AS latest_response_status,
    array_agg(DISTINCT inv.source ORDER BY inv.source) AS sources,
    array_agg(DISTINCT inv.request_path) FILTER (WHERE inv.request_path IS NOT NULL) AS request_paths
  FROM public.edge_function_runtime_invocations inv
  JOIN (
    SELECT
      function_name,
      max(invoked_at) AS latest_invoked_at
    FROM public.edge_function_runtime_invocations
    WHERE invoked_at >= now() - interval '24 hours'
    GROUP BY function_name
  ) latest
    ON latest.function_name = inv.function_name
  WHERE inv.invoked_at >= now() - interval '24 hours'
  GROUP BY inv.function_name, latest.latest_invoked_at
)
SELECT
  recent.function_name,
  recent.invocation_count,
  recent.last_invoked_at,
  recent.latest_response_status,
  recent.sources,
  recent.request_paths,
  CASE
    WHEN allowed.function_name IS NULL THEN 'not_in_deploy_prod'
    WHEN allowed.is_active IS FALSE THEN 'inactive_in_deploy_prod'
    ELSE 'active'
  END AS stale_reason
FROM recent
LEFT JOIN public.deploy_prod_function_list allowed
  ON allowed.function_name = recent.function_name
WHERE allowed.function_name IS NULL
   OR allowed.is_active IS FALSE;

COMMENT ON VIEW public.stale_ef_runtime_invocations IS
  'Edge Functions invoked in the last 24h but missing/inactive in deploy-prod.yml allowlist.';

GRANT SELECT ON public.deploy_prod_function_list TO authenticated;

REVOKE ALL ON public.edge_function_runtime_invocations FROM anon, authenticated;
REVOKE ALL ON public.stale_ef_runtime_invocations FROM anon, authenticated;

GRANT ALL ON public.deploy_prod_function_list TO service_role;
GRANT ALL ON public.edge_function_runtime_invocations TO service_role;
GRANT SELECT ON public.stale_ef_runtime_invocations TO service_role;
