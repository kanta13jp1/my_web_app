-- Aggregate-only plan economics readiness evidence for Tiger Issue #4744.
-- This intentionally reports measured source values and explicit gaps instead
-- of inventing gross margin, CAC, payback, churn, or LTV.

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
      'rawCostEstimate', 'stored ai_usage_log value; currency and provider coverage are not defined'
    ),
    'plans', v_plans,
    'decisionMetrics', jsonb_build_object(
      'grossMarginRate', NULL,
      'customerAcquisitionCostYen', NULL,
      'paybackMonths', NULL,
      'monthlyChurnRate', NULL,
      'lifetimeValueYen', NULL
    ),
    'missingInputs', jsonb_build_array(
      'provider-cost currency and complete AI request coverage',
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
  'Service-role-only aggregate plan economics readiness evidence for Tiger Issue #4744.';
