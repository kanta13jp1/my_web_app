const SUPPORTED_ACQUISITION_SIGNALS = new Set([
  "touch_landing",
  "touch_profile",
  "touch_import",
  "touch_public_memo",
  "touch_referral",
  "touch_comparison",
  "touch_guitar_gallery",
  "touch_x_first_user_growth",
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
]);

export function isSupportedAcquisitionSignal(signalKey: string): boolean {
  return SUPPORTED_ACQUISITION_SIGNALS.has(signalKey) ||
    /^touch_comparison_[a-z0-9_-]{1,64}$/i.test(signalKey);
}
