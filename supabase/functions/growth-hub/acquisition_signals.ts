const SUPPORTED_ACQUISITION_SIGNALS = new Set([
  "touch_landing",
  "touch_profile",
  "touch_import",
  "touch_public_memo",
  "touch_referral",
  "touch_comparison",
  "touch_guitar_gallery",
  "touch_x_first_user_growth",
  "touch_zenn_first_user_growth",
  "import_preview_notion",
  "import_preview_evernote",
  "import_preview_markdown",
  "import_signup_cta",
  "public_memo_signup_cta",
  "x_first_user_trial_intent",
  "x_first_user_feedback_summary",
  "x_first_user_feedback_memo",
  "x_first_user_feedback_search",
  "x_first_user_feedback_x_intent",
  "signup_submit_landing",
  "signup_submit_profile",
  "signup_submit_x_first_user_growth",
  "signup_submit_zenn_first_user_growth",
  "signup_submit_import",
  "signup_submit_public_memo",
  "signup_submit_referral",
  "signup_submit_comparison",
  "signup_submit_guitar",
  // R24: 公開データトラッカー (/public/local-election-700) の着地と CTA。
  "touch_public_tracker",
  "public_tracker_signup_cta",
  "signup_submit_public_tracker",
  // Issue #3667: 課金ページの view → upgrade → checkout outcome。
  "funnel_billing_view",
  "funnel_upgrade_click",
  "funnel_checkout_success",
  "funnel_checkout_cancel",
  // Issue #4091: all browser analytics writes cross the rate-limited Edge
  // boundary, including share and authentication diagnostics.
  "x_share",
  "line",
  "facebook",
  "copy_link",
  "share_x",
  "share_line",
  "share_facebook",
  "share_copy",
  "share_note",
  "public_memo_share",
  "public_memo_copy",
  "funnel_trial_run",
  "funnel_save_cta",
  "funnel_magic_link_attempt",
  "funnel_magic_link_send",
  "funnel_magic_link_fail_invalid_email",
  "funnel_magic_link_fail_rate_limit",
  "funnel_magic_link_fail_delivery_config",
  "funnel_magic_link_fail_redirect",
  "funnel_magic_link_fail_network",
  "funnel_magic_link_fail_unknown",
  "funnel_google_oauth_start",
  "funnel_google_oauth_fail_cancelled",
  "funnel_google_oauth_fail_rate_limit",
  "funnel_google_oauth_fail_provider_config",
  "funnel_google_oauth_fail_redirect",
  "funnel_google_oauth_fail_callback_exchange",
  "funnel_google_oauth_fail_unknown",
  "funnel_inbox_open",
]);

export function isSupportedAcquisitionSignal(signalKey: string): boolean {
  return SUPPORTED_ACQUISITION_SIGNALS.has(signalKey) ||
    /^touch_comparison_[a-z0-9_-]{1,64}$/i.test(signalKey) ||
    /^lp_exp_h(0[1-9]|10)_(control|treatment)_(view|mobile_view|hero_cta|intent|trial|trial_fallback|save_cta|signup_submit|mobile_signup_submit|signup_complete|sticky_cta|feature_outcome_trial|feature_catalog_expand)$/
      .test(
        signalKey,
      ) ||
    /^activation_exp_a(0[1-9]|10)_(control|treatment)_(onboarding_view|intent_selected|first_action_started|first_action_completed|onboarding_completed|value_recap_view|billing_view|supporter_checkout|pro_checkout|checkout_return)$/
      .test(
        signalKey,
      );
}
