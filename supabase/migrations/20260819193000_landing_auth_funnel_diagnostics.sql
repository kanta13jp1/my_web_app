-- Allow privacy-safe counters for the Google-first registration handoff and
-- categorized Magic Link failures. No email address or provider error text is
-- stored in app_analytics.
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
         'funnel_magic_link_attempt',
         'funnel_magic_link_send',
         'funnel_magic_link_fail_invalid_email',
         'funnel_magic_link_fail_rate_limit',
         'funnel_magic_link_fail_delivery_config',
         'funnel_magic_link_fail_redirect',
         'funnel_magic_link_fail_network',
         'funnel_magic_link_fail_unknown',
         'funnel_google_oauth_start',
         'funnel_inbox_open'
       )
       OR p_source_key ~ '^lp_exp_h(0[1-9]|10)_(control|treatment)_(view|mobile_view|hero_cta|intent|trial|trial_fallback|save_cta|signup_submit|mobile_signup_submit|signup_complete|sticky_cta|feature_outcome_trial|feature_catalog_expand)$'
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
