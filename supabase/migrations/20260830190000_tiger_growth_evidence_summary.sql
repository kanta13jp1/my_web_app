-- Privacy-safe operating evidence for Tiger review Issue #4744.
-- Raw acquisition, usage, and billing rows stay behind their existing RLS
-- boundaries. Only service-role callers can read the aggregate JSON result.

CREATE INDEX IF NOT EXISTS first_user_acquisition_events_user_stage_idx
  ON public.first_user_acquisition_events (
    auth_user_id,
    stage,
    first_occurred_at
  )
  WHERE auth_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS user_feature_usage_report_idx
  ON public.user_feature_usage (tapped_at DESC, feature_route, user_id)
  WHERE user_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.get_tiger_growth_evidence_summary(
  p_window_days integer DEFAULT 90
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_window_days integer := GREATEST(30, LEAST(COALESCE(p_window_days, 90), 365));
  v_generated_at timestamptz := CURRENT_TIMESTAMP;
  v_window_started_at timestamptz;
  v_cohorts jsonb;
  v_routes jsonb;
BEGIN
  v_window_started_at := v_generated_at
    - pg_catalog.make_interval(days => v_window_days);

  WITH source_catalog(source) AS (
    VALUES ('x'::text), ('zenn'::text)
  ),
  acquisition AS (
    SELECT DISTINCT ON (event.auth_user_id)
      event.auth_user_id AS user_id,
      event.utm_source AS source,
      event.first_occurred_at AS acquired_at
    FROM public.first_user_acquisition_events AS event
    WHERE event.auth_user_id IS NOT NULL
      AND event.stage = 'signup_complete'
      AND event.first_occurred_at >= v_window_started_at
      AND event.first_occurred_at <= v_generated_at
    ORDER BY
      event.auth_user_id,
      event.first_occurred_at,
      event.utm_source
  ),
  metrics AS (
    SELECT
      source_catalog.source,
      COUNT(acquisition.user_id) AS acquired_users,
      COUNT(acquisition.user_id) FILTER (
        WHERE acquisition.acquired_at <= v_generated_at - INTERVAL '1 day'
      ) AS d1_eligible_users,
      COUNT(acquisition.user_id) FILTER (
        WHERE acquisition.acquired_at <= v_generated_at - INTERVAL '1 day'
          AND EXISTS (
            SELECT 1
            FROM public.user_feature_usage AS usage
            WHERE usage.user_id = acquisition.user_id
              AND usage.tapped_at >= acquisition.acquired_at + INTERVAL '1 day'
              AND usage.tapped_at < acquisition.acquired_at + INTERVAL '2 days'
          )
      ) AS d1_retained_users,
      COUNT(acquisition.user_id) FILTER (
        WHERE acquisition.acquired_at <= v_generated_at - INTERVAL '7 days'
      ) AS d7_eligible_users,
      COUNT(acquisition.user_id) FILTER (
        WHERE acquisition.acquired_at <= v_generated_at - INTERVAL '7 days'
          AND EXISTS (
            SELECT 1
            FROM public.user_feature_usage AS usage
            WHERE usage.user_id = acquisition.user_id
              AND usage.tapped_at >= acquisition.acquired_at + INTERVAL '7 days'
              AND usage.tapped_at < acquisition.acquired_at + INTERVAL '8 days'
          )
      ) AS d7_retained_users,
      COUNT(acquisition.user_id) FILTER (
        WHERE acquisition.acquired_at <= v_generated_at - INTERVAL '30 days'
      ) AS d30_eligible_users,
      COUNT(acquisition.user_id) FILTER (
        WHERE acquisition.acquired_at <= v_generated_at - INTERVAL '30 days'
          AND EXISTS (
            SELECT 1
            FROM public.user_feature_usage AS usage
            WHERE usage.user_id = acquisition.user_id
              AND usage.tapped_at >= acquisition.acquired_at + INTERVAL '30 days'
              AND usage.tapped_at < acquisition.acquired_at + INTERVAL '31 days'
          )
      ) AS d30_retained_users,
      COUNT(acquisition.user_id) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.billing_subscriptions AS subscription
          WHERE subscription.user_id = acquisition.user_id
            AND subscription.tier IN ('pro', 'team')
            AND subscription.status = 'active'
            AND subscription.created_at >= acquisition.acquired_at
        )
      ) AS paid_converted_users
    FROM source_catalog
    LEFT JOIN acquisition ON acquisition.source = source_catalog.source
    GROUP BY source_catalog.source
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'source', metrics.source,
        'acquiredUsers', metrics.acquired_users,
        'd1EligibleUsers', metrics.d1_eligible_users,
        'd1RetainedUsers', metrics.d1_retained_users,
        'd7EligibleUsers', metrics.d7_eligible_users,
        'd7RetainedUsers', metrics.d7_retained_users,
        'd30EligibleUsers', metrics.d30_eligible_users,
        'd30RetainedUsers', metrics.d30_retained_users,
        'paidConvertedUsers', metrics.paid_converted_users
      )
      ORDER BY metrics.source
    ),
    '[]'::jsonb
  )
  INTO v_cohorts
  FROM metrics;

  WITH route_user_activity AS (
    SELECT
      usage.feature_route AS route,
      usage.user_id,
      COUNT(*) AS tap_count
    FROM public.user_feature_usage AS usage
    WHERE usage.user_id IS NOT NULL
      AND usage.tapped_at >= v_window_started_at
      AND usage.tapped_at <= v_generated_at
      AND NULLIF(BTRIM(usage.feature_route), '') IS NOT NULL
    GROUP BY usage.feature_route, usage.user_id
  ),
  route_metrics AS (
    SELECT
      activity.route,
      COUNT(*) AS unique_users,
      SUM(activity.tap_count) AS tap_count,
      COUNT(*) FILTER (WHERE activity.tap_count >= 2) AS returning_users,
      COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.billing_subscriptions AS subscription
          WHERE subscription.user_id = activity.user_id
            AND subscription.tier IN ('pro', 'team')
            AND subscription.status = 'active'
        )
      ) AS paid_users
    FROM route_user_activity AS activity
    GROUP BY activity.route
    ORDER BY unique_users DESC, tap_count DESC, activity.route
    LIMIT 50
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'route', route_metrics.route,
        'uniqueUsers', route_metrics.unique_users,
        'tapCount', route_metrics.tap_count,
        'returningUsers', route_metrics.returning_users,
        'paidUsers', route_metrics.paid_users
      )
      ORDER BY
        route_metrics.unique_users DESC,
        route_metrics.tap_count DESC,
        route_metrics.route
    ),
    '[]'::jsonb
  )
  INTO v_routes
  FROM route_metrics;

  RETURN jsonb_build_object(
    'generatedAt', v_generated_at,
    'windowDays', v_window_days,
    'windowStartedAt', v_window_started_at,
    'privacy', jsonb_build_object(
      'aggregateOnly', true,
      'containsUserIds', false,
      'containsVisitorIds', false,
      'containsEmail', false,
      'containsName', false,
      'containsPromptText', false
    ),
    'definitions', jsonb_build_object(
      'acquisition', 'earliest linked signup_complete in the report window',
      'retention', 'feature-route tap in the exact D1, D7, or D30 24-hour window',
      'paidConversion', 'currently active Pro or Team subscription created after acquisition',
      'returningRouteUser', 'at least two taps on the route in the report window'
    ),
    'cohorts', v_cohorts,
    'routes', v_routes
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_tiger_growth_evidence_summary(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_tiger_growth_evidence_summary(integer)
  TO service_role;

COMMENT ON FUNCTION public.get_tiger_growth_evidence_summary(integer) IS
  'Service-role-only aggregate acquisition, retention, paid-conversion, and route evidence for Tiger review Issue #4744.';
