-- Measure activation-to-paid experiments with one row per authenticated user,
-- arm, and stage. The ledger deliberately stores no email, IP address, user
-- agent, prompt, challenge text, or other user-supplied content.
CREATE TABLE public.activation_experiment_events (
  auth_user_id uuid NOT NULL
    REFERENCES auth.users (id) ON DELETE CASCADE,
  hypothesis_id text NOT NULL
    CHECK (hypothesis_id ~ '^a(0[1-9]|10)$'),
  variant text NOT NULL
    CHECK (variant IN ('control', 'treatment')),
  stage text NOT NULL
    CHECK (
      stage IN (
        'onboarding_view',
        'intent_selected',
        'first_action_started',
        'first_action_completed',
        'onboarding_completed',
        'value_recap_view',
        'billing_view',
        'supporter_checkout',
        'pro_checkout',
        'checkout_return'
      )
    ),
  first_occurred_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (auth_user_id, hypothesis_id, variant, stage)
);

COMMENT ON TABLE public.activation_experiment_events IS
  'Privacy-minimized unique-user ledger for A01-A10 activation-to-paid experiments.';

CREATE INDEX activation_experiment_events_first_occurred_idx
  ON public.activation_experiment_events (first_occurred_at DESC);

ALTER TABLE public.activation_experiment_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.activation_experiment_events
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.activation_experiment_events TO service_role;

CREATE OR REPLACE FUNCTION public.record_activation_experiment_event(
  p_event_key text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_auth_user_id uuid := auth.uid();
  v_hypothesis_id text;
  v_variant text;
  v_stage text;
  v_inserted_rows integer := 0;
BEGIN
  IF v_auth_user_id IS NULL THEN
    RAISE EXCEPTION 'authenticated user is required'
      USING ERRCODE = '42501';
  END IF;

  IF lower(COALESCE(auth.jwt() ->> 'is_anonymous', 'false')) = 'true' THEN
    RAISE EXCEPTION 'non-anonymous user is required'
      USING ERRCODE = '42501';
  END IF;

  IF p_event_key IS NULL
     OR length(p_event_key) > 160
     OR p_event_key !~ '^activation_exp_a(0[1-9]|10)_(control|treatment)_(onboarding_view|intent_selected|first_action_started|first_action_completed|onboarding_completed|value_recap_view|billing_view|supporter_checkout|pro_checkout|checkout_return)$' THEN
    RAISE EXCEPTION 'invalid activation experiment event key';
  END IF;

  v_hypothesis_id := split_part(p_event_key, '_', 3);
  v_variant := split_part(p_event_key, '_', 4);
  v_stage := regexp_replace(
    p_event_key,
    '^activation_exp_a(0[1-9]|10)_(control|treatment)_',
    ''
  );

  INSERT INTO public.activation_experiment_events (
    auth_user_id,
    hypothesis_id,
    variant,
    stage
  )
  VALUES (
    v_auth_user_id,
    v_hypothesis_id,
    v_variant,
    v_stage
  )
  ON CONFLICT (auth_user_id, hypothesis_id, variant, stage) DO NOTHING;

  GET DIAGNOSTICS v_inserted_rows = ROW_COUNT;
  RETURN v_inserted_rows = 1;
END;
$$;

COMMENT ON FUNCTION public.record_activation_experiment_event(text) IS
  'Records one activation experiment stage per signed-in non-anonymous user.';

REVOKE ALL ON FUNCTION public.record_activation_experiment_event(text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_activation_experiment_event(text)
  TO authenticated, service_role;

CREATE VIEW public.activation_experiment_arm_stats
WITH (security_invoker = true)
AS
WITH experiment_arms(hypothesis_id, variant) AS (
  VALUES
    ('a01', 'control'), ('a01', 'treatment'),
    ('a02', 'control'), ('a02', 'treatment'),
    ('a03', 'control'), ('a03', 'treatment'),
    ('a04', 'control'), ('a04', 'treatment'),
    ('a05', 'control'), ('a05', 'treatment'),
    ('a06', 'control'), ('a06', 'treatment'),
    ('a07', 'control'), ('a07', 'treatment'),
    ('a08', 'control'), ('a08', 'treatment'),
    ('a09', 'control'), ('a09', 'treatment'),
    ('a10', 'control'), ('a10', 'treatment')
)
SELECT
  arm.hypothesis_id,
  arm.variant,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'onboarding_view')
    AS unique_onboarding_views,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'intent_selected')
    AS unique_intent_selections,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'first_action_started')
    AS unique_first_action_starts,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'first_action_completed')
    AS unique_first_action_completions,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'onboarding_completed')
    AS unique_onboarding_completions,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'value_recap_view')
    AS unique_value_recap_views,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'billing_view')
    AS unique_billing_views,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'supporter_checkout')
    AS unique_supporter_checkouts,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'pro_checkout')
    AS unique_pro_checkouts,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (
      WHERE event.stage IN ('supporter_checkout', 'pro_checkout')
    ) AS unique_checkout_starts,
  COUNT(DISTINCT event.auth_user_id)
    FILTER (WHERE event.stage = 'checkout_return')
    AS unique_checkout_returns,
  MIN(event.first_occurred_at) AS first_event_at,
  MAX(event.first_occurred_at) AS last_event_at
FROM experiment_arms AS arm
LEFT JOIN public.activation_experiment_events AS event
  ON event.hypothesis_id = arm.hypothesis_id
 AND event.variant = arm.variant
GROUP BY arm.hypothesis_id, arm.variant;

COMMENT ON VIEW public.activation_experiment_arm_stats IS
  'Service-role-only aggregate counts for all 20 A01-A10 experiment arms.';

REVOKE ALL ON TABLE public.activation_experiment_arm_stats
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.activation_experiment_arm_stats TO service_role;
