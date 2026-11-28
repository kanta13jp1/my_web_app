-- Surface live AI Hub daily USD costs and attribution counts in
-- get_tiger_plan_economics_summary without inventing per-plan allocations.

CREATE OR REPLACE FUNCTION public.get_tiger_plan_economics_summary(
  p_window_days integer DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  v_window_days integer := GREATEST(1, LEAST(COALESCE(p_window_days, 30), 366));
  v_generated_at timestamptz := CURRENT_TIMESTAMP;
  v_window_started_at timestamptz;
  v_plans jsonb;
  v_ai_hub_cost_window jsonb;
BEGIN
  v_window_started_at := v_generated_at
    - pg_catalog.make_interval(days => v_window_days);

  WITH plan_catalog(plan, list_price_yen) AS (
    VALUES ('pro'::text, 980::integer), ('team'::text, 2980::integer)
  ),
  active_subscriptions AS (
    SELECT
      subscription.user_id,
      subscription.tier AS plan,
      subscription.created_at
    FROM public.billing_subscriptions AS subscription
    WHERE subscription.status = 'active'
      AND subscription.tier IN ('pro', 'team')
  ),
  plan_counts AS (
    SELECT
      catalog.plan,
      catalog.list_price_yen,
      COUNT(subscription.user_id) AS active_paid_customers,
      COUNT(subscription.user_id) FILTER (
        WHERE subscription.created_at >= v_window_started_at
          AND subscription.created_at <= v_generated_at
      ) AS current_active_customers_created_in_window
    FROM plan_catalog AS catalog
    LEFT JOIN active_subscriptions AS subscription
      ON subscription.plan = catalog.plan
    GROUP BY catalog.plan, catalog.list_price_yen
  ),
  usage_by_plan AS (
    SELECT
      subscription.plan,
      COUNT(usage.id) AS ai_usage_rows,
      COALESCE(SUM(usage.input_tokens), 0) AS input_tokens,
      COALESCE(SUM(usage.output_tokens), 0) AS output_tokens,
      COALESCE(SUM(usage.total_tokens), 0) AS total_tokens,
      COALESCE(SUM(usage.cost_estimate), 0) AS raw_cost_estimate
    FROM active_subscriptions AS subscription
    LEFT JOIN public.ai_usage_log AS usage
      ON usage.user_id = subscription.user_id
      AND usage.created_at >= v_window_started_at
      AND usage.created_at <= v_generated_at
    GROUP BY subscription.plan
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'plan', counts.plan,
        'activePaidCustomers', counts.active_paid_customers,
        'listPriceYen', counts.list_price_yen,
        'listPriceMrrYen', counts.active_paid_customers * counts.list_price_yen,
        'currentActiveCustomersCreatedInWindow',
          counts.current_active_customers_created_in_window,
        'aiUsageRows', COALESCE(usage.ai_usage_rows, 0),
        'inputTokens', COALESCE(usage.input_tokens, 0),
        'outputTokens', COALESCE(usage.output_tokens, 0),
        'totalTokens', COALESCE(usage.total_tokens, 0),
        'rawCostEstimate', COALESCE(usage.raw_cost_estimate, 0)
      )
      ORDER BY counts.plan
    ),
    '[]'::jsonb
  )
  INTO v_plans
  FROM plan_counts AS counts
  LEFT JOIN usage_by_plan AS usage ON usage.plan = counts.plan;

  WITH daily_features AS (
    SELECT
      daily.feature_key,
      COALESCE(SUM(daily.request_count), 0)::bigint AS request_count,
      COALESCE(SUM(daily.success_count), 0)::bigint AS success_count,
      GREATEST(
        COALESCE(SUM(daily.request_count - daily.success_count), 0),
        0
      )::bigint AS failed_count,
      COALESCE(SUM(daily.api_cost_usd), 0)::numeric AS estimated_cost_usd
    FROM public.ai_feature_usage_cost_daily AS daily
    WHERE daily.usage_date >= (v_window_started_at AT TIME ZONE 'UTC')::date
      AND daily.usage_date <= (v_generated_at AT TIME ZONE 'UTC')::date
    GROUP BY daily.feature_key
  ),
  daily_totals AS (
    SELECT
      COALESCE(SUM(request_count), 0)::bigint AS total_requests,
      COALESCE(SUM(success_count), 0)::bigint AS success_count,
      COALESCE(SUM(failed_count), 0)::bigint AS failed_count,
      COALESCE(SUM(estimated_cost_usd), 0)::numeric AS estimated_cost_usd
    FROM daily_features
  ),
  top_features AS (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'featureKey', f.feature_key,
          'requestCount', f.request_count,
          'successCount', f.success_count,
          'failedCount', f.failed_count,
          'estimatedCostUsd', f.estimated_cost_usd
        )
        ORDER BY
          f.request_count DESC,
          f.estimated_cost_usd DESC,
          f.feature_key ASC
      ),
      '[]'::jsonb
    ) AS items
    FROM (
      SELECT *
      FROM daily_features
      ORDER BY
        request_count DESC,
        estimated_cost_usd DESC,
        feature_key ASC
      LIMIT 10
    ) AS f
  ),
  log_attribution AS (
    SELECT
      COUNT(*) FILTER (WHERE logs.user_id IS NOT NULL)::bigint
        AS plan_attributed_requests,
      COUNT(*) FILTER (WHERE logs.user_id IS NULL)::bigint
        AS unattributed_requests
    FROM public.ai_hub_chat_logs AS logs
    WHERE logs.provider IS DISTINCT FROM 'all'
      AND logs.created_at >= v_window_started_at
      AND logs.created_at <= v_generated_at
  )
  SELECT jsonb_build_object(
    'source', 'public.ai_feature_usage_cost_daily',
    'currency', 'USD',
    'totalRequests', totals.total_requests,
    'successCount', totals.success_count,
    'failedCount', totals.failed_count,
    'estimatedCostUsd', totals.estimated_cost_usd,
    'planAttributedRequests', attr.plan_attributed_requests,
    'unattributedRequests', attr.unattributed_requests,
    'byFeature', top.items
  )
  INTO v_ai_hub_cost_window
  FROM daily_totals AS totals
  CROSS JOIN top_features AS top
  CROSS JOIN log_attribution AS attr;

  RETURN jsonb_build_object(
    'generatedAt', v_generated_at,
    'windowDays', v_window_days,
    'windowStartedAt', v_window_started_at,
    'privacy', jsonb_build_object(
      'aggregateOnly', true,
      'containsUserIds', false,
      'containsCustomerIds', false,
      'containsEmail', false,
      'containsPromptText', false
    ),
    'definitions', jsonb_build_object(
      'planAttribution', 'current active subscription tier at report time',
      'listPriceMrrYen', 'active paid customers multiplied by configured list price; not collected revenue',
      'rawCostEstimate', 'legacy ai_usage_log value retained for compatibility; zero when inactive',
      'aiHubCostWindow', 'live UTC daily aggregate from public.ai_feature_usage_cost_daily in USD alongside ai_hub_chat_logs attribution counts'
    ),
    'plans', v_plans,
    'aiHubCostWindow', v_ai_hub_cost_window,
    'decisionMetrics', jsonb_build_object(
      'grossMarginRate', NULL,
      'customerAcquisitionCostYen', NULL,
      'paybackMonths', NULL,
      'monthlyChurnRate', NULL,
      'lifetimeValueYen', NULL
    ),
    'missingInputs', jsonb_build_array(
      'provider-cost currency and complete AI request coverage',
      'user-to-plan attribution on ai_hub_chat_logs',
      'plan-level non-AI variable costs',
      'plan-level acquisition spend',
      'subscription state history for beginning, new, and churned customers',
      'collected subscription revenue net of refunds and fees'
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_tiger_plan_economics_summary(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_tiger_plan_economics_summary(integer)
  TO service_role;

COMMENT ON FUNCTION public.get_tiger_plan_economics_summary(integer) IS
  'Service-role-only aggregate plan economics and AI Hub daily USD cost evidence for Tiger Issue #4744.';
