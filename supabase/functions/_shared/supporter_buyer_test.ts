import {
  assert,
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  classifySupporterBuyer,
  isExternalRevenueCandidate,
  normalizeSupporterBuyerContext,
  supporterBuyerStripeParams,
} from "./supporter_buyer.ts";

const OWNER_USER_ID = "11111111-1111-4111-8111-111111111111";
const EXTERNAL_USER_ID = "22222222-2222-4222-8222-222222222222";

Deno.test("supporter buyer excludes profile and auth administrators", () => {
  for (
    const context of [
      classifySupporterBuyer({
        userId: OWNER_USER_ID,
        profileIsAdmin: true,
      }),
      classifySupporterBuyer({
        userId: OWNER_USER_ID,
        profileRole: "admin",
      }),
      classifySupporterBuyer({
        userId: OWNER_USER_ID,
        authRole: "ADMIN",
      }),
    ]
  ) {
    assertEquals(context, {
      authUserId: OWNER_USER_ID,
      classification: "admin_self",
    });
    assertFalse(isExternalRevenueCandidate(context));
  }
});

Deno.test("signed-in non-admin supporter is an external revenue candidate", () => {
  const context = classifySupporterBuyer({
    userId: EXTERNAL_USER_ID,
    profileIsAdmin: false,
    profileRole: "user",
  });

  assertEquals(context, {
    authUserId: EXTERNAL_USER_ID,
    classification: "authenticated_non_admin",
  });
  assert(isExternalRevenueCandidate(context));
  assertEquals(supporterBuyerStripeParams(context), {
    "metadata[buyer_classification]": "authenticated_non_admin",
    "payment_intent_data[metadata][buyer_classification]":
      "authenticated_non_admin",
    "metadata[auth_user_id]": EXTERNAL_USER_ID,
    "payment_intent_data[metadata][auth_user_id]": EXTERNAL_USER_ID,
  });
});

Deno.test("anonymous and invalid metadata cannot become revenue evidence", () => {
  const anonymous = classifySupporterBuyer({
    userId: "anonymous-auth-user",
    isAnonymous: true,
  });
  assertEquals(anonymous, {
    authUserId: null,
    classification: "anonymous_unclassified",
  });
  assertFalse(isExternalRevenueCandidate(anonymous));
  assertEquals(supporterBuyerStripeParams(anonymous), {
    "metadata[buyer_classification]": "anonymous_unclassified",
    "payment_intent_data[metadata][buyer_classification]":
      "anonymous_unclassified",
  });

  assertEquals(
    normalizeSupporterBuyerContext("", "authenticated_non_admin"),
    anonymous,
  );
  assertEquals(
    normalizeSupporterBuyerContext(EXTERNAL_USER_ID, "forged-value"),
    anonymous,
  );
  assertEquals(
    normalizeSupporterBuyerContext(
      "not-a-uuid",
      "authenticated_non_admin",
    ),
    anonymous,
  );
});
