export type StripeMode = "live" | "test" | "unknown";

export type StripeAccountReadinessSummary = {
  mode: StripeMode;
  account_id_redacted: string;
  country: string;
  default_currency: string;
  details_submitted: boolean;
  charges_enabled: boolean;
  payouts_enabled: boolean;
  requirements: {
    disabled_reason: string;
    current_deadline: string;
    currently_due: string[];
    past_due: string[];
    pending_verification: string[];
    errors: Array<{
      code: string;
      requirement: string;
    }>;
  };
  stage:
    | "ready_for_external_payment_and_bank_payout"
    | "live_secret_required"
    | "verification_pending"
    | "requirements_action_required"
    | "payments_enabled_payouts_blocked"
    | "charges_blocked"
    | "account_not_enabled";
  ready_for_external_payment: boolean;
  ready_for_bank_payout: boolean;
  next_action: string;
};

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value : "";
}

function asStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === "string")
    : [];
}

function deadlineIso(value: unknown): string {
  if (typeof value !== "number" || !Number.isFinite(value)) return "";
  return new Date(value * 1000).toISOString();
}

const STRIPE_OBJECT_ID_PATTERN =
  /\b(?:acct|person|cus|pm|pi|seti|src|tok|card|ba|ch|py|po|tr|bt|txn|evt|file|link|req)_[A-Za-z0-9]+\b/g;

export function stripeModeFromSecretKey(secretKey: string): StripeMode {
  const normalized = secretKey.trim();
  if (normalized.startsWith("sk_live_") || normalized.startsWith("rk_live_")) {
    return "live";
  }
  if (normalized.startsWith("sk_test_") || normalized.startsWith("rk_test_")) {
    return "test";
  }
  return "unknown";
}

export function redactStripeIdentifier(identifier: unknown): string {
  const normalized = asString(identifier);
  if (!normalized) return "";
  const separator = normalized.indexOf("_");
  const prefix = separator >= 0
    ? normalized.slice(0, separator + 1)
    : normalized.slice(0, Math.min(5, normalized.length));
  const suffix = normalized.slice(-4);
  return `${prefix}...${suffix}`;
}

export function redactStripeAccountId(accountId: unknown): string {
  return redactStripeIdentifier(accountId);
}

export function redactStripeRequirementReference(
  requirement: unknown,
): string {
  return asString(requirement).replace(
    STRIPE_OBJECT_ID_PATTERN,
    (identifier) => redactStripeIdentifier(identifier),
  );
}

export function summarizeStripeAccountReadiness(
  account: Record<string, unknown>,
  secretKey: string,
): StripeAccountReadinessSummary {
  const mode = stripeModeFromSecretKey(secretKey);
  const requirements = asRecord(account.requirements);
  const currentlyDue = asStringArray(requirements.currently_due).map(
    redactStripeRequirementReference,
  );
  const pastDue = asStringArray(requirements.past_due).map(
    redactStripeRequirementReference,
  );
  const pendingVerification = asStringArray(
    requirements.pending_verification,
  ).map(redactStripeRequirementReference);
  const requirementErrors = Array.isArray(requirements.errors)
    ? requirements.errors.map((value) => {
      const error = asRecord(value);
      return {
        code: asString(error.code),
        requirement: redactStripeRequirementReference(error.requirement),
      };
    })
    : [];
  const disabledReason = asString(requirements.disabled_reason);
  const chargesEnabled = account.charges_enabled === true;
  const payoutsEnabled = account.payouts_enabled === true;
  const readyForExternalPayment = mode === "live" && chargesEnabled;
  const readyForBankPayout = mode === "live" && payoutsEnabled;

  let stage: StripeAccountReadinessSummary["stage"];
  let nextAction: string;
  if (mode !== "live") {
    stage = "live_secret_required";
    nextAction = "Configure a live Stripe secret or restricted key.";
  } else if (
    chargesEnabled &&
    payoutsEnabled &&
    !disabledReason &&
    pastDue.length === 0
  ) {
    stage = "ready_for_external_payment_and_bank_payout";
    nextAction =
      "Proceed with the approved first-buyer experiment and verify the paid webhook.";
  } else if (pendingVerification.length > 0) {
    stage = "verification_pending";
    nextAction =
      "Wait for Stripe verification and rerun this gate before requesting payment.";
  } else if (
    disabledReason ||
    currentlyDue.length > 0 ||
    pastDue.length > 0 ||
    requirementErrors.length > 0
  ) {
    stage = "requirements_action_required";
    nextAction =
      "Resolve the listed Stripe account requirements, then rerun this gate.";
  } else if (chargesEnabled && !payoutsEnabled) {
    stage = "payments_enabled_payouts_blocked";
    nextAction =
      "Do not request payment yet; enable Stripe payouts and rerun this gate.";
  } else if (!chargesEnabled && payoutsEnabled) {
    stage = "charges_blocked";
    nextAction =
      "Enable live charges in Stripe before running the first-buyer experiment.";
  } else {
    stage = "account_not_enabled";
    nextAction =
      "Review Stripe account status and complete the requested verification.";
  }

  return {
    mode,
    account_id_redacted: redactStripeAccountId(account.id),
    country: asString(account.country),
    default_currency: asString(account.default_currency),
    details_submitted: account.details_submitted === true,
    charges_enabled: chargesEnabled,
    payouts_enabled: payoutsEnabled,
    requirements: {
      disabled_reason: disabledReason,
      current_deadline: deadlineIso(requirements.current_deadline),
      currently_due: currentlyDue,
      past_due: pastDue,
      pending_verification: pendingVerification,
      errors: requirementErrors,
    },
    stage,
    ready_for_external_payment: readyForExternalPayment,
    ready_for_bank_payout: readyForBankPayout,
    next_action: nextAction,
  };
}
