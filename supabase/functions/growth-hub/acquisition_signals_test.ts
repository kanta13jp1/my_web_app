import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { isSupportedAcquisitionSignal } from "./acquisition_signals.ts";

Deno.test("billing funnel acquisition signals are supported", () => {
  for (
    const signal of [
      "funnel_billing_view",
      "funnel_upgrade_click",
      "funnel_checkout_success",
      "funnel_checkout_cancel",
    ]
  ) {
    assertEquals(isSupportedAcquisitionSignal(signal), true);
  }
});

Deno.test("first-user campaign signals support X and Zenn attribution", () => {
  for (
    const signal of [
      "touch_x_first_user_growth",
      "signup_submit_x_first_user_growth",
      "touch_zenn_first_user_growth",
      "signup_submit_zenn_first_user_growth",
    ]
  ) {
    assertEquals(isSupportedAcquisitionSignal(signal), true);
  }
});

Deno.test("acquisition signal allowlist rejects unknown funnel events", () => {
  assertEquals(isSupportedAcquisitionSignal("funnel_checkout_unknown"), false);
  assertEquals(isSupportedAcquisitionSignal("touch_comparison_notion"), true);
});

Deno.test("public share and auth diagnostics use the same Edge allowlist", () => {
  for (
    const signal of [
      "share_x",
      "public_memo_share",
      "funnel_magic_link_fail_network",
      "funnel_google_oauth_fail_callback_exchange",
      "lp_exp_h10_treatment_signup_complete",
      "activation_exp_a10_control_checkout_return",
    ]
  ) {
    assertEquals(isSupportedAcquisitionSignal(signal), true);
  }
});
