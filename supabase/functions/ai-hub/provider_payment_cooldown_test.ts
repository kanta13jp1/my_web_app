import {
  DEFAULT_BUDGET_TIER_PROVIDERS,
  isProviderPaymentRequired,
  PAYMENT_EXHAUSTED_COOLDOWN_MS,
  parseDisabledProviders,
  ProviderPaymentCooldownTracker,
  QUOTA_FALLBACK_CHAIN,
  selectEligibleProviders,
  shouldSkipProviderForBilling,
} from "./provider_payment_cooldown.ts";

function assertEquals<T>(actual: T, expected: T, message?: string): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actual !== expected && actualJson !== expectedJson) {
    throw new Error(
      `${message ? `${message}: ` : ""}expected ${expectedJson}, got ${actualJson}`,
    );
  }
}

Deno.test("isProviderPaymentRequired detects 402 and quota exhaustion payloads", () => {
  assertEquals(
    isProviderPaymentRequired(
      402,
      '{"error":{"message":"You need positive balance to do inference."}}',
    ),
    true,
  );
  assertEquals(
    isProviderPaymentRequired(429, '{"error":{"message":"You have no credits remaining."}}'),
    true,
  );
  assertEquals(
    isProviderPaymentRequired(
      400,
      '{"error":{"message":"Your credit balance is too low to access the Anthropic API."}}',
    ),
    true,
  );
  assertEquals(
    isProviderPaymentRequired(422, "guardrail_blocked[stage=input][categories=pii_credit_card]"),
    false,
  );
  assertEquals(isProviderPaymentRequired(500, "internal upstream error"), false);
  assertEquals(isProviderPaymentRequired(200, "ok"), false);
});

Deno.test("DEFAULT_BUDGET_TIER_PROVIDERS excludes deepinfra and fallback prioritizes google/nebius", () => {
  assertEquals(DEFAULT_BUDGET_TIER_PROVIDERS.includes("deepinfra"), false);
  assertEquals(DEFAULT_BUDGET_TIER_PROVIDERS.includes("sambanova"), true);
  assertEquals(QUOTA_FALLBACK_CHAIN[0], "google");
  assertEquals(QUOTA_FALLBACK_CHAIN[1], "nebius");
});

Deno.test("ProviderPaymentCooldownTracker skips during cooldown and recovers after expiry", () => {
  const tracker = new ProviderPaymentCooldownTracker(1_000);
  const start = 10_000;

  assertEquals(tracker.isInCooldown("deepinfra", start), false);
  tracker.markExhausted("DeepInfra", start);
  assertEquals(tracker.isInCooldown("deepinfra", start + 500), true);
  assertEquals(tracker.remainingCooldownMs("deepinfra", start + 500), 500);

  const skipped = shouldSkipProviderForBilling("deepinfra", tracker, undefined, start + 500);
  assertEquals(skipped, { skip: true, reason: "payment_cooldown" });

  assertEquals(tracker.isInCooldown("deepinfra", start + 1_000), false);
  assertEquals(
    shouldSkipProviderForBilling("deepinfra", tracker, undefined, start + 1_000),
    { skip: false, reason: null },
  );
  assertEquals(PAYMENT_EXHAUSTED_COOLDOWN_MS, 15 * 60 * 1000);
});

Deno.test("parseDisabledProviders and selectEligibleProviders filter disabled and cooled providers", () => {
  const disabled = parseDisabledProviders(" deepinfra , openai ,, ");
  assertEquals(disabled.has("deepinfra"), true);
  assertEquals(disabled.has("openai"), true);
  assertEquals(disabled.has("google"), false);

  const tracker = new ProviderPaymentCooldownTracker(5_000);
  tracker.markExhausted("anthropic", 1_000);

  const skipDisabled = shouldSkipProviderForBilling(
    "openai",
    tracker,
    "deepinfra,openai",
    2_000,
  );
  assertEquals(skipDisabled, { skip: true, reason: "disabled" });

  const eligible = selectEligibleProviders(
    QUOTA_FALLBACK_CHAIN,
    tracker,
    "deepinfra,openai",
    2_000,
  );
  assertEquals(eligible, ["google", "nebius"]);
});
