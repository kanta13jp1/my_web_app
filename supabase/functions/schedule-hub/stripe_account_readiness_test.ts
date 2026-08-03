import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  redactStripeAccountId,
  stripeModeFromSecretKey,
  summarizeStripeAccountReadiness,
} from "./stripe_account_readiness.ts";

Deno.test("stripe mode recognizes live and restricted live keys", () => {
  assertEquals(stripeModeFromSecretKey("sk_live_example"), "live");
  assertEquals(stripeModeFromSecretKey("rk_live_example"), "live");
  assertEquals(stripeModeFromSecretKey("sk_test_example"), "test");
  assertEquals(stripeModeFromSecretKey("unexpected"), "unknown");
});

Deno.test("account id is redacted", () => {
  assertEquals(redactStripeAccountId("acct_123456789"), "acct_...6789");
});

Deno.test("live enabled account is ready for payment and payout", () => {
  const summary = summarizeStripeAccountReadiness(
    {
      id: "acct_123456789",
      country: "JP",
      default_currency: "jpy",
      details_submitted: true,
      charges_enabled: true,
      payouts_enabled: true,
      requirements: {
        disabled_reason: null,
        currently_due: [],
        past_due: [],
        pending_verification: [],
        errors: [],
      },
    },
    "rk_live_example",
  );

  assertEquals(summary.stage, "ready_for_external_payment_and_bank_payout");
  assertEquals(summary.ready_for_external_payment, true);
  assertEquals(summary.ready_for_bank_payout, true);
  assertEquals(summary.account_id_redacted, "acct_...6789");
});

Deno.test("pending verification blocks the bank-payout gate", () => {
  const summary = summarizeStripeAccountReadiness(
    {
      charges_enabled: true,
      payouts_enabled: false,
      requirements: {
        disabled_reason: null,
        currently_due: [],
        past_due: [],
        pending_verification: ["representative.verification.document"],
        errors: [],
      },
    },
    "sk_live_example",
  );

  assertEquals(summary.stage, "verification_pending");
  assertEquals(summary.ready_for_external_payment, true);
  assertFalse(summary.ready_for_bank_payout);
});

Deno.test("past-due requirements take the action-required stage", () => {
  const summary = summarizeStripeAccountReadiness(
    {
      charges_enabled: false,
      payouts_enabled: false,
      requirements: {
        disabled_reason: "requirements.past_due",
        currently_due: ["external_account"],
        past_due: ["external_account"],
        pending_verification: [],
        errors: [{
          code: "information_missing",
          requirement: "external_account",
          reason: "A bank account is required.",
        }],
      },
    },
    "sk_live_example",
  );

  assertEquals(summary.stage, "requirements_action_required");
  assertEquals(summary.requirements.currently_due, ["external_account"]);
  assertEquals(summary.requirements.errors, [{
    code: "information_missing",
    requirement: "external_account",
  }]);
});

Deno.test("test key never passes the live readiness gate", () => {
  const summary = summarizeStripeAccountReadiness(
    {
      charges_enabled: true,
      payouts_enabled: true,
      requirements: {},
    },
    "sk_test_example",
  );

  assertEquals(summary.stage, "live_secret_required");
  assertFalse(summary.ready_for_external_payment);
  assertFalse(summary.ready_for_bank_payout);
});
