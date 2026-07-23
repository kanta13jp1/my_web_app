-- Deduplicate LP experiment funnels by a random browser-scoped visitor UUID.
-- This ledger intentionally stores no email, IP address, user agent, prompt,
-- answer, or browser fingerprint.
CREATE TABLE public.landing_experiment_events (
  visitor_id uuid NOT NULL,
  hypothesis_id text NOT NULL
    CHECK (hypothesis_id ~ '^h(0[1-9]|10)$'),
  variant text NOT NULL
    CHECK (variant IN ('control', 'treatment')),
  stage text NOT NULL
    CHECK (
      stage IN (
        'view',
        'hero_cta',
        'intent',
        'trial',
        'trial_fallback',
        'save_cta',
        'signup_submit',
        'signup_complete',
        'sticky_cta',
        'feature_outcome_trial',
        'feature_catalog_expand'
      )
    ),
  first_occurred_at timestamptz NOT NULL DEFAULT now(),
  auth_user_id uuid,
  auth_is_anonymous boolean,
  PRIMARY KEY (visitor_id, hypothesis_id, variant, stage),
  CHECK (
    (auth_user_id IS NULL AND auth_is_anonymous IS NULL)
    OR (auth_user_id IS NOT NULL AND auth_is_anonymous IS NOT NULL)
  )
);

CREATE INDEX landing_experiment_events_first_occurred_idx
  ON public.landing_experiment_events (first_occurred_at DESC);

ALTER TABLE public.landing_experiment_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.landing_experiment_events
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.landing_experiment_events TO service_role;

CREATE OR REPLACE FUNCTION public.record_landing_experiment_event(
  p_visitor_id uuid,
  p_event_key text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_hypothesis_id text;
  v_variant text;
  v_stage text;
  v_auth_user_id uuid := auth.uid();
  v_auth_is_anonymous boolean;
  v_inserted_rows integer := 0;
BEGIN
  IF p_visitor_id IS NULL THEN
    RAISE EXCEPTION 'visitor ID is required';
  END IF;

  IF p_event_key IS NULL
     OR length(p_event_key) > 160
     OR p_event_key !~ '^lp_exp_h(0[1-9]|10)_(control|treatment)_(view|hero_cta|intent|trial|trial_fallback|save_cta|signup_submit|signup_complete|sticky_cta|feature_outcome_trial|feature_catalog_expand)$' THEN
    RAISE EXCEPTION 'invalid LP experiment event key';
  END IF;

  v_hypothesis_id := split_part(p_event_key, '_', 3);
  v_variant := split_part(p_event_key, '_', 4);
  v_stage := regexp_replace(
    p_event_key,
    '^lp_exp_h(0[1-9]|10)_(control|treatment)_',
    ''
  );

  IF v_auth_user_id IS NOT NULL THEN
    v_auth_is_anonymous := COALESCE(
      (auth.jwt() ->> 'is_anonymous')::boolean,
      false
    );
  END IF;

  INSERT INTO public.landing_experiment_events (
    visitor_id,
    hypothesis_id,
    variant,
    stage,
    auth_user_id,
    auth_is_anonymous
  )
  VALUES (
    p_visitor_id,
    v_hypothesis_id,
    v_variant,
    v_stage,
    v_auth_user_id,
    v_auth_is_anonymous
  )
  ON CONFLICT (visitor_id, hypothesis_id, variant, stage) DO NOTHING;

  GET DIAGNOSTICS v_inserted_rows = ROW_COUNT;
  RETURN v_inserted_rows = 1;
END;
$$;

REVOKE ALL ON FUNCTION public.record_landing_experiment_event(uuid, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_landing_experiment_event(uuid, text)
  TO anon, authenticated, service_role;

CREATE VIEW public.landing_experiment_arm_stats
WITH (security_invoker = true)
AS
WITH experiment_arms(hypothesis_id, variant) AS (
  VALUES
    ('h01', 'control'), ('h01', 'treatment'),
    ('h02', 'control'), ('h02', 'treatment'),
    ('h03', 'control'), ('h03', 'treatment'),
    ('h04', 'control'), ('h04', 'treatment'),
    ('h05', 'control'), ('h05', 'treatment'),
    ('h06', 'control'), ('h06', 'treatment'),
    ('h07', 'control'), ('h07', 'treatment'),
    ('h08', 'control'), ('h08', 'treatment'),
    ('h09', 'control'), ('h09', 'treatment'),
    ('h10', 'control'), ('h10', 'treatment')
)
SELECT
  arm.hypothesis_id,
  arm.variant,
  COUNT(DISTINCT event.visitor_id)
    FILTER (WHERE event.stage = 'view') AS unique_views,
  COUNT(DISTINCT event.visitor_id)
    FILTER (WHERE event.stage = 'trial') AS unique_trials,
  COUNT(DISTINCT event.visitor_id)
    FILTER (WHERE event.stage = 'save_cta') AS unique_save_ctas,
  COUNT(DISTINCT event.visitor_id)
    FILTER (WHERE event.stage = 'signup_submit') AS unique_signup_submits,
  COUNT(DISTINCT event.visitor_id)
    FILTER (WHERE event.stage = 'signup_complete') AS unique_signup_completes,
  COUNT(DISTINCT event.visitor_id) FILTER (
    WHERE event.stage = 'signup_complete'
      AND event.auth_user_id IS NOT NULL
      AND event.auth_is_anonymous = false
  ) AS non_anonymous_signup_completes,
  MIN(event.first_occurred_at) AS first_event_at,
  MAX(event.first_occurred_at) AS last_event_at
FROM experiment_arms AS arm
LEFT JOIN public.landing_experiment_events AS event
  ON event.hypothesis_id = arm.hypothesis_id
 AND event.variant = arm.variant
GROUP BY arm.hypothesis_id, arm.variant;

REVOKE ALL ON TABLE public.landing_experiment_arm_stats
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.landing_experiment_arm_stats TO service_role;

-- Keep the pre-existing daily aggregate compatible with every current LP stage.
CREATE OR REPLACE FUNCTION public.increment_app_analytics_source_detail(
  p_source_key text,
  p_event_date date DEFAULT (timezone('Asia/Tokyo', now()))::date,
  p_share_increment integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_today date := (timezone('Asia/Tokyo', now()))::date;
BEGIN
  IF p_source_key IS NULL
     OR btrim(p_source_key) = ''
     OR length(p_source_key) > 160
     OR NOT (
       p_source_key IN (
         'x_share',
         'line',
         'facebook',
         'copy_link',
         'share_x',
         'share_line',
         'share_facebook',
         'share_copy',
         'funnel_trial_run',
         'funnel_save_cta',
         'funnel_magic_link_send',
         'funnel_inbox_open'
       )
       OR p_source_key ~ '^lp_exp_h(0[1-9]|10)_(control|treatment)_(view|hero_cta|intent|trial|trial_fallback|save_cta|signup_submit|signup_complete|sticky_cta|feature_outcome_trial|feature_catalog_expand)$'
       OR p_source_key ~ '^activation_exp_a(0[1-9]|10)_(control|treatment)_(onboarding_view|intent_selected|first_action_started|first_action_completed|onboarding_completed|value_recap_view|billing_view|supporter_checkout|pro_checkout|checkout_return)$'
     ) THEN
    RAISE EXCEPTION 'invalid analytics source key';
  END IF;

  IF p_event_date IS NULL
     OR p_event_date < v_today - 1
     OR p_event_date > v_today + 1 THEN
    RAISE EXCEPTION 'invalid analytics event date';
  END IF;

  IF p_share_increment IS NULL
     OR p_share_increment < 0
     OR p_share_increment > 1 THEN
    RAISE EXCEPTION 'invalid share increment';
  END IF;

  INSERT INTO public.app_analytics AS analytics (
    date,
    landing_views,
    conversions,
    share_count,
    source_details
  )
  VALUES (
    p_event_date,
    0,
    0,
    p_share_increment,
    jsonb_build_object(p_source_key, 1)
  )
  ON CONFLICT (date) DO UPDATE
  SET
    share_count = COALESCE(analytics.share_count, 0)
      + p_share_increment,
    source_details = COALESCE(
      analytics.source_details,
      '{}'::jsonb
    ) || jsonb_build_object(
      p_source_key,
      CASE
        WHEN (analytics.source_details ->> p_source_key) ~ '^[0-9]+$'
          THEN (analytics.source_details ->> p_source_key)::integer
        ELSE 0
      END + 1
    );
END;
$$;

REVOKE ALL ON FUNCTION public.increment_app_analytics_source_detail(
  text,
  date,
  integer
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.increment_app_analytics_source_detail(
  text,
  date,
  integer
) TO anon, authenticated, service_role;
