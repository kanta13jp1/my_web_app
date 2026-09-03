-- Extend the privacy-minimized first_user_growth cohort to the two reviewed
-- launch channels. The raw table remains RLS-enabled and service-role-only.
ALTER TABLE public.first_user_acquisition_events
  DROP CONSTRAINT IF EXISTS first_user_acquisition_events_utm_source_check;

ALTER TABLE public.first_user_acquisition_events
  ADD CONSTRAINT first_user_acquisition_events_utm_source_check
  CHECK (utm_source IN ('x', 'zenn', 'producthunt', 'hackernews')) NOT VALID;

ALTER TABLE public.first_user_acquisition_events
  VALIDATE CONSTRAINT first_user_acquisition_events_utm_source_check;

COMMENT ON TABLE public.first_user_acquisition_events IS
  'Privacy-minimized unique-visitor funnel for approved first_user_growth acquisition channels.';

-- Keep the service-role-only analytics RPC allowlist aligned with the launch
-- signals emitted by growth-hub. CREATE OR REPLACE preserves the function's
-- existing owner and grants; the explicit grants below reassert least privilege.
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
        'touch_producthunt_first_user_growth',
        'touch_hackernews_first_user_growth',
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
        'signup_submit_producthunt_first_user_growth',
        'signup_submit_hackernews_first_user_growth',
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
