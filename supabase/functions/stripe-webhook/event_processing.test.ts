import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  checkoutPaymentDecision,
  claimStripeWebhookEvent,
  completeStripeWebhookEvent,
  failStripeWebhookEvent,
  processStripeWebhookEventOnce,
  StripeWebhookRpcClient,
} from "./event_processing.ts";

class FakeRpcClient implements StripeWebhookRpcClient {
  calls: Array<{ functionName: string; args: Record<string, unknown> }> = [];
  response: { data: unknown; error: { message: string } | null } = {
    data: null,
    error: null,
  };

  rpc(functionName: string, args: Record<string, unknown>) {
    this.calls.push({ functionName, args });
    return Promise.resolve(this.response);
  }
}

Deno.test("checkoutPaymentDecision only fulfills paid sessions", () => {
  assertEquals(checkoutPaymentDecision({ payment_status: "paid" }), {
    shouldFulfill: true,
    paymentStatus: "paid",
    reason: null,
  });
  assertEquals(checkoutPaymentDecision({ payment_status: "unpaid" }), {
    shouldFulfill: false,
    paymentStatus: "unpaid",
    reason: "checkout_not_paid",
  });
  assertEquals(checkoutPaymentDecision({}), {
    shouldFulfill: false,
    paymentStatus: "",
    reason: "checkout_not_paid",
  });
});

Deno.test("claimStripeWebhookEvent claims a new or retryable event", async () => {
  const client = new FakeRpcClient();
  client.response = { data: true, error: null };

  assertEquals(
    await claimStripeWebhookEvent(
      client,
      "evt_123",
      "checkout.session.completed",
    ),
    true,
  );
  assertEquals(client.calls, [{
    functionName: "claim_stripe_webhook_event",
    args: {
      p_event_id: "evt_123",
      p_event_type: "checkout.session.completed",
    },
  }]);
});

Deno.test("claimStripeWebhookEvent rejects an already processed event", async () => {
  const client = new FakeRpcClient();
  client.response = { data: false, error: null };

  assertEquals(
    await claimStripeWebhookEvent(client, "evt_duplicate", "invoice.paid"),
    false,
  );
});

Deno.test("event lifecycle RPC helpers preserve audit details", async () => {
  const client = new FakeRpcClient();
  const longError = "x".repeat(4500);

  await completeStripeWebhookEvent(client, "evt_done");
  await failStripeWebhookEvent(client, "evt_failed", longError);

  assertEquals(client.calls[0], {
    functionName: "complete_stripe_webhook_event",
    args: { p_event_id: "evt_done" },
  });
  assertEquals(client.calls[1].functionName, "fail_stripe_webhook_event");
  assertEquals(client.calls[1].args.p_event_id, "evt_failed");
  assertEquals(String(client.calls[1].args.p_error).length, 4000);
});

Deno.test("event lifecycle helpers surface database errors", async () => {
  const client = new FakeRpcClient();
  client.response = { data: null, error: { message: "database unavailable" } };

  await assertRejects(
    () => claimStripeWebhookEvent(client, "evt_123", "invoice.paid"),
    Error,
    "database unavailable",
  );
});

Deno.test("processStripeWebhookEventOnce does not run duplicate side effects", async () => {
  const client = new FakeRpcClient();
  client.response = { data: false, error: null };
  let sideEffectCalls = 0;

  const result = await processStripeWebhookEventOnce(
    client,
    "evt_duplicate",
    "checkout.session.completed",
    () => {
      sideEffectCalls += 1;
      return Promise.resolve("fulfilled");
    },
  );

  assertEquals(result, { duplicate: true });
  assertEquals(sideEffectCalls, 0);
  assertEquals(client.calls.length, 1);
});

Deno.test("processStripeWebhookEventOnce completes a claimed event", async () => {
  const client = new FakeRpcClient();
  client.response = { data: true, error: null };

  const result = await processStripeWebhookEventOnce(
    client,
    "evt_new",
    "checkout.session.completed",
    () => Promise.resolve("fulfilled"),
  );

  assertEquals(result, { duplicate: false, value: "fulfilled" });
  assertEquals(client.calls.map((call) => call.functionName), [
    "claim_stripe_webhook_event",
    "complete_stripe_webhook_event",
  ]);
});

Deno.test("processStripeWebhookEventOnce records a retryable failure", async () => {
  const client = new FakeRpcClient();
  client.response = { data: true, error: null };

  await assertRejects(
    () =>
      processStripeWebhookEventOnce(
        client,
        "evt_failed",
        "checkout.session.completed",
        () => Promise.reject(new Error("temporary failure")),
      ),
    Error,
    "temporary failure",
  );
  assertEquals(client.calls.map((call) => call.functionName), [
    "claim_stripe_webhook_event",
    "fail_stripe_webhook_event",
  ]);
});
