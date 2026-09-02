export const SUPPORTER_BUYER_CLASSIFICATIONS = [
  "admin_self",
  "authenticated_non_admin",
  "anonymous_unclassified",
] as const;

export type SupporterBuyerClassification =
  (typeof SUPPORTER_BUYER_CLASSIFICATIONS)[number];

export interface SupporterBuyerFacts {
  userId?: string | null;
  isAnonymous?: boolean;
  profileIsAdmin?: boolean;
  profileRole?: string | null;
  authRole?: string | null;
}

export interface SupporterBuyerContext {
  authUserId: string | null;
  classification: SupporterBuyerClassification;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function normalizedRole(value: string | null | undefined): string {
  return (value ?? "").trim().toLowerCase();
}

export function classifySupporterBuyer(
  facts: SupporterBuyerFacts,
): SupporterBuyerContext {
  const userId = (facts.userId ?? "").trim();
  if (!UUID_PATTERN.test(userId) || facts.isAnonymous === true) {
    return {
      authUserId: null,
      classification: "anonymous_unclassified",
    };
  }

  const isAdmin = facts.profileIsAdmin === true ||
    normalizedRole(facts.profileRole) === "admin" ||
    normalizedRole(facts.authRole) === "admin";

  return {
    authUserId: userId,
    classification: isAdmin ? "admin_self" : "authenticated_non_admin",
  };
}

export function normalizeSupporterBuyerContext(
  authUserId: unknown,
  classification: unknown,
): SupporterBuyerContext {
  const userId = typeof authUserId === "string" ? authUserId.trim() : "";
  const value = typeof classification === "string" ? classification.trim() : "";
  const valid = SUPPORTER_BUYER_CLASSIFICATIONS.includes(
    value as SupporterBuyerClassification,
  );

  if (
    !valid || value === "anonymous_unclassified" ||
    !UUID_PATTERN.test(userId)
  ) {
    return {
      authUserId: null,
      classification: "anonymous_unclassified",
    };
  }

  return {
    authUserId: userId,
    classification: value as SupporterBuyerClassification,
  };
}

export function supporterBuyerStripeParams(
  context: SupporterBuyerContext,
): Record<string, string> {
  const values: Record<string, string> = {
    buyer_classification: context.classification,
  };
  if (context.authUserId) values.auth_user_id = context.authUserId;

  const params: Record<string, string> = {};
  for (const [field, value] of Object.entries(values)) {
    params[`metadata[${field}]`] = value;
    params[`payment_intent_data[metadata][${field}]`] = value;
  }
  return params;
}

export function isExternalRevenueCandidate(
  context: SupporterBuyerContext,
): boolean {
  return context.classification === "authenticated_non_admin" &&
    context.authUserId !== null;
}
