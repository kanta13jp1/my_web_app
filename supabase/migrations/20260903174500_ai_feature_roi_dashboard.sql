-- Issue #4130: configurable AI feature ROI measurement.
-- Business-value estimates are intentionally user-entered and default to zero.

CREATE TABLE IF NOT EXISTS public.ai_feature_roi_parameters (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  feature_key text NOT NULL,
  minutes_saved_per_success numeric NOT NULL DEFAULT 0,
  hourly_value_usd numeric NOT NULL DEFAULT 0,
  direct_cost_saving_usd_per_success numeric NOT NULL DEFAULT 0,
  avoided_loss_usd_per_success numeric NOT NULL DEFAULT 0,
  value_created_usd_per_success numeric NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, feature_key),
  CONSTRAINT ai_feature_roi_parameters_feature_key_check CHECK (
    feature_key ~ '^[a-z0-9_./:-]{1,64}$'
  ),
  CONSTRAINT ai_feature_roi_parameters_minutes_check CHECK (
    minutes_saved_per_success BETWEEN 0 AND 1440
  ),
  CONSTRAINT ai_feature_roi_parameters_hourly_value_check CHECK (
    hourly_value_usd BETWEEN 0 AND 10000
  ),
  CONSTRAINT ai_feature_roi_parameters_direct_saving_check CHECK (
    direct_cost_saving_usd_per_success BETWEEN 0 AND 1000000
  ),
  CONSTRAINT ai_feature_roi_parameters_avoided_loss_check CHECK (
    avoided_loss_usd_per_success BETWEEN 0 AND 1000000
  ),
  CONSTRAINT ai_feature_roi_parameters_value_created_check CHECK (
    value_created_usd_per_success BETWEEN 0 AND 1000000
  )
);

ALTER TABLE public.ai_feature_roi_parameters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_feature_roi_parameters FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_feature_roi_parameters_select_own
  ON public.ai_feature_roi_parameters;
CREATE POLICY ai_feature_roi_parameters_select_own
  ON public.ai_feature_roi_parameters
  FOR SELECT
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS ai_feature_roi_parameters_insert_own
  ON public.ai_feature_roi_parameters;
CREATE POLICY ai_feature_roi_parameters_insert_own
  ON public.ai_feature_roi_parameters
  FOR INSERT
  TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS ai_feature_roi_parameters_update_own
  ON public.ai_feature_roi_parameters;
CREATE POLICY ai_feature_roi_parameters_update_own
  ON public.ai_feature_roi_parameters
  FOR UPDATE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS ai_feature_roi_parameters_delete_own
  ON public.ai_feature_roi_parameters;
CREATE POLICY ai_feature_roi_parameters_delete_own
  ON public.ai_feature_roi_parameters
  FOR DELETE
  TO authenticated
  USING ((SELECT auth.uid()) = user_id);

REVOKE ALL PRIVILEGES ON TABLE public.ai_feature_roi_parameters
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE public.ai_feature_roi_parameters TO authenticated;
GRANT ALL PRIVILEGES
  ON TABLE public.ai_feature_roi_parameters TO service_role;

CREATE OR REPLACE VIEW public.ai_feature_usage_cost_daily
WITH (security_invoker = true)
AS
SELECT
  (created_at AT TIME ZONE 'UTC')::date AS usage_date,
  COALESCE(
    NULLIF(
      LEFT(
        TRIM(BOTH '_' FROM REGEXP_REPLACE(
          LOWER(COALESCE(
            NULLIF(TRIM(routing_use_case), ''),
            NULLIF(TRIM(action), ''),
            'unknown'
          )),
          '[^a-z0-9_./:-]+',
          '_',
          'g'
        )),
        64
      ),
      ''
    ),
    'unknown'
  ) AS feature_key,
  COUNT(*)::bigint AS request_count,
  COUNT(*) FILTER (WHERE success IS DISTINCT FROM false)::bigint
    AS success_count,
  COALESCE(SUM(GREATEST(COALESCE(estimated_cost_usd, 0), 0)), 0)::numeric
    AS api_cost_usd
FROM public.ai_hub_chat_logs
WHERE provider IS DISTINCT FROM 'all'
GROUP BY 1, 2;

REVOKE ALL PRIVILEGES ON TABLE public.ai_feature_usage_cost_daily
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.ai_feature_usage_cost_daily TO service_role;

COMMENT ON TABLE public.ai_feature_roi_parameters IS
  'Per-user, explicitly configured AI feature ROI assumptions; zero means no estimated benefit.';
COMMENT ON VIEW public.ai_feature_usage_cost_daily IS
  'Service-role-only daily AI feature usage and API cost aggregates; contains no user identifiers or prompt content.';
