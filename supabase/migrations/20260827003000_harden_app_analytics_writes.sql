-- Issue #4091: browser clients may read only the daily aggregate projection.
-- Raw rows can also contain service-owned metadata, so neither row visibility
-- nor column privileges may expose the generic storage fields.
ALTER TABLE public.app_analytics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public access" ON public.app_analytics;
DROP POLICY IF EXISTS app_analytics_public_read ON public.app_analytics;

REVOKE ALL PRIVILEGES ON TABLE public.app_analytics
FROM PUBLIC, anon, authenticated;

GRANT SELECT (
  date,
  landing_views,
  conversions,
  share_count,
  source_details
) ON TABLE public.app_analytics TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.app_analytics
TO service_role;

CREATE POLICY app_analytics_public_read
ON public.app_analytics
FOR SELECT
TO anon, authenticated
USING (
  source IS NULL
  AND COALESCE(metadata, '{}'::jsonb) = '{}'::jsonb
);

-- Edge Functions use this private receipt table to make anonymous analytics
-- idempotent per source, actor fingerprint, and JST day. Browser roles receive
-- no privileges and no policy on the table.
CREATE TABLE IF NOT EXISTS public.app_analytics_event_receipts (
  event_date date NOT NULL,
  source_key text NOT NULL,
  actor_hash text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (event_date, source_key, actor_hash),
  CONSTRAINT app_analytics_event_receipts_actor_hash_check
    CHECK (actor_hash ~ '^[0-9a-f]{64}$')
);

ALTER TABLE public.app_analytics_event_receipts ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS app_analytics_event_receipts_actor_day_idx
ON public.app_analytics_event_receipts (event_date, actor_hash);

REVOKE ALL PRIVILEGES ON TABLE public.app_analytics_event_receipts
FROM PUBLIC, anon, authenticated;
GRANT ALL PRIVILEGES ON TABLE public.app_analytics_event_receipts
TO service_role;

CREATE OR REPLACE FUNCTION public.is_app_analytics_source_key_allowed(
  p_source_key text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $$
  SELECT p_source_key IS NOT NULL
    AND btrim(p_source_key) <> ''
    AND length(p_source_key) <= 160
    AND (
      p_source_key IN (
        'x_share',
        'line',
        'facebook',
        'copy_link',
        'share_x',
        'share_line',
        'share_facebook',
        'share_copy',
        'share_note',
        'public_memo_share',
        'public_memo_copy',
        'touch_landing',
        'touch_profile',
        'touch_import',
        'touch_public_memo',
        'touch_referral',
        'touch_comparison',
        'touch_guitar_gallery',
        'touch_x_first_user_growth',
        'touch_zenn_first_user_growth',
        'touch_public_tracker',
        'import_preview_notion',
        'import_preview_evernote',
        'import_preview_markdown',
        'import_signup_cta',
        'public_memo_signup_cta',
        'public_tracker_signup_cta',
        'x_first_user_trial_intent',
        'x_first_user_feedback_summary',
        'x_first_user_feedback_memo',
        'x_first_user_feedback_search',
        'x_first_user_feedback_x_intent',
        'signup_submit_landing',
        'signup_submit_profile',
        'signup_submit_x_first_user_growth',
        'signup_submit_zenn_first_user_growth',
        'signup_submit_import',
        'signup_submit_public_memo',
        'signup_submit_referral',
        'signup_submit_comparison',
        'signup_submit_guitar',
        'signup_submit_public_tracker',
        'funnel_billing_view',
        'funnel_upgrade_click',
        'funnel_checkout_success',
        'funnel_checkout_cancel',
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
        'funnel_google_oauth_fail_cancelled',
        'funnel_google_oauth_fail_rate_limit',
        'funnel_google_oauth_fail_provider_config',
        'funnel_google_oauth_fail_redirect',
        'funnel_google_oauth_fail_callback_exchange',
        'funnel_google_oauth_fail_unknown',
        'funnel_inbox_open'
      )
      OR p_source_key ~* '^touch_comparison_[a-z0-9_-]{1,64}$'
      OR p_source_key ~ '^lp_exp_h(0[1-9]|10)_(control|treatment)_(view|mobile_view|hero_cta|intent|trial|trial_fallback|save_cta|signup_submit|mobile_signup_submit|signup_complete|sticky_cta|feature_outcome_trial|feature_catalog_expand)$'
      OR p_source_key ~ '^activation_exp_a(0[1-9]|10)_(control|treatment)_(onboarding_view|intent_selected|first_action_started|first_action_completed|onboarding_completed|value_recap_view|billing_view|supporter_checkout|pro_checkout|checkout_return)$'
    );
$$;

REVOKE ALL ON FUNCTION public.is_app_analytics_source_key_allowed(text)
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_app_analytics_source_key_allowed(text)
TO service_role;

-- This is the only public-event aggregation primitive. It is service-role only;
-- growth-hub supplies a server-derived actor hash and one transaction both
-- claims the daily receipt and updates the aggregate.
CREATE OR REPLACE FUNCTION public.record_app_analytics_event(
  p_source_key text,
  p_event_date date DEFAULT (timezone('Asia/Tokyo', now()))::date,
  p_share_increment integer DEFAULT 0,
  p_actor_hash text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_today date := (timezone('Asia/Tokyo', now()))::date;
  v_inserted integer := 0;
BEGIN
  IF NOT public.is_app_analytics_source_key_allowed(p_source_key) THEN
    RAISE EXCEPTION 'invalid analytics source key';
  END IF;

  IF p_event_date IS NULL OR p_event_date <> v_today THEN
    RAISE EXCEPTION 'invalid analytics event date';
  END IF;

  IF p_share_increment IS NULL
     OR p_share_increment < 0
     OR p_share_increment > 1 THEN
    RAISE EXCEPTION 'invalid share increment';
  END IF;

  IF p_actor_hash IS NULL OR p_actor_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid analytics actor hash';
  END IF;

  -- Serialize one actor/day bucket so source-key rotation cannot bypass the
  -- hard daily cap or grow source_details without bound from one origin.
  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_actor_hash || ':' || p_event_date::text, 0)
  );
  IF (
    SELECT count(*)
    FROM public.app_analytics_event_receipts
    WHERE event_date = p_event_date
      AND actor_hash = p_actor_hash
  ) >= 32 THEN
    RETURN false;
  END IF;

  INSERT INTO public.app_analytics_event_receipts (
    event_date,
    source_key,
    actor_hash
  )
  VALUES (p_event_date, p_source_key, p_actor_hash)
  ON CONFLICT DO NOTHING;

  GET DIAGNOSTICS v_inserted = ROW_COUNT;
  IF v_inserted = 0 THEN
    RETURN false;
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
    share_count = LEAST(
      COALESCE(analytics.share_count, 0)::bigint + p_share_increment,
      2147483647
    )::integer,
    source_details = COALESCE(
      analytics.source_details,
      '{}'::jsonb
    ) || jsonb_build_object(
      p_source_key,
      LEAST(
        CASE
          WHEN (analytics.source_details ->> p_source_key) ~ '^[0-9]{1,10}$'
            THEN LEAST(
              (analytics.source_details ->> p_source_key)::bigint,
              2147483646
            )
          ELSE 0
        END + 1,
        2147483647
      )
    );

  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.record_app_analytics_event(
  text,
  date,
  integer,
  text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_app_analytics_event(
  text,
  date,
  integer,
  text
) TO service_role;

-- Retain legacy server-side contracts, but remove all browser EXECUTE access.
-- Both functions use the same JST day boundary as the new Edge-only path.
CREATE OR REPLACE FUNCTION public.increment_share_count()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_today date := (timezone('Asia/Tokyo', now()))::date;
BEGIN
  INSERT INTO public.app_analytics AS analytics (
    date,
    landing_views,
    conversions,
    share_count
  )
  VALUES (v_today, 0, 0, 1)
  ON CONFLICT (date) DO UPDATE
  SET share_count = LEAST(
    COALESCE(analytics.share_count, 0)::bigint + 1,
    2147483647
  )::integer;
END;
$$;

REVOKE ALL ON FUNCTION public.increment_share_count()
FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_share_count()
TO service_role;

CREATE OR REPLACE FUNCTION public.increment_app_analytics_source_detail(
  p_source_key text,
  p_event_date date DEFAULT (timezone('Asia/Tokyo', now()))::date,
  p_share_increment integer DEFAULT 0
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_today date := (timezone('Asia/Tokyo', now()))::date;
BEGIN
  IF NOT public.is_app_analytics_source_key_allowed(p_source_key) THEN
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
    share_count = LEAST(
      COALESCE(analytics.share_count, 0)::bigint + p_share_increment,
      2147483647
    )::integer,
    source_details = COALESCE(
      analytics.source_details,
      '{}'::jsonb
    ) || jsonb_build_object(
      p_source_key,
      LEAST(
        CASE
          WHEN (analytics.source_details ->> p_source_key) ~ '^[0-9]{1,10}$'
            THEN LEAST(
              (analytics.source_details ->> p_source_key)::bigint,
              2147483646
            )
          ELSE 0
        END + 1,
        2147483647
      )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.increment_app_analytics_source_detail(
  text,
  date,
  integer
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.increment_app_analytics_source_detail(
  text,
  date,
  integer
) TO service_role;
