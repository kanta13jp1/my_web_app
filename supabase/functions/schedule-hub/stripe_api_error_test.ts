import {
  assertEquals,
  assertFalse,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  isMissingStripeCustomer,
  StripeApiError,
  stripeApiErrorDetails,
  stripeApiErrorFromResponse,
} from "./stripe_api_error.ts";

Deno.test("Stripe resource_missing for customer is repairable", () => {
  const error = stripeApiErrorFromResponse(400, {
    error: {
      code: "resource_missing",
      param: "customer",
      message: "No such customer: cus_stale",
    },
  });

  assertEquals(isMissingStripeCustomer(error), true);
  assertEquals(stripeApiErrorDetails(error), {
    status: 400,
    code: "resource_missing",
    param: "customer",
  });
});

Deno.test("other Stripe resource failures are not customer repairs", () => {
  const error = stripeApiErrorFromResponse(400, {
    error: {
      code: "resource_missing",
      param: "line_items[0][price]",
      message: "No such price",
    },
  });

  assertFalse(isMissingStripeCustomer(error));
});

Deno.test("Stripe error details never include the upstream message", () => {
  const error = new StripeApiError(
    400,
    "resource_missing",
    "customer",
    "No such customer: cus_sensitive",
  );

  const details = stripeApiErrorDetails(error);
  assertEquals(details, {
    status: 400,
    code: "resource_missing",
    param: "customer",
  });
  assertFalse(JSON.stringify(details).includes("cus_sensitive"));
});

Deno.test("non-Stripe errors do not expose structured details", () => {
  assertEquals(stripeApiErrorDetails(new Error("database detail")), null);
  assertFalse(isMissingStripeCustomer(new Error("resource_missing")));
});
