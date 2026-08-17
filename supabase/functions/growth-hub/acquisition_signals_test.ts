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

Deno.test("acquisition signal allowlist rejects unknown funnel events", () => {
  assertEquals(isSupportedAcquisitionSignal("funnel_checkout_unknown"), false);
  assertEquals(isSupportedAcquisitionSignal("touch_comparison_notion"), true);
});
