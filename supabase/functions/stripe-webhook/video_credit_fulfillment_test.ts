import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  fulfillVideoCreditCheckout,
  revokeRefundedVideoCredits,
} from "./video_credit_fulfillment.ts";

function fakeClient(
  result: Record<string, unknown> = {},
): { client: SupabaseClient; calls: Array<Record<string, unknown>> } {
  const calls: Array<Record<string, unknown>> = [];
  const client = {
    rpc: (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      return Promise.resolve({ data: result, error: null });
    },
  } as unknown as SupabaseClient;
  return { client, calls };
}

Deno.test("non-video checkout is ignored", async () => {
  const { client, calls } = fakeClient();
  assertEquals(
    await fulfillVideoCreditCheckout(client, { metadata: { offer: "other" } }),
    { handled: false },
  );
  assertEquals(calls.length, 0);
});

Deno.test("signed paid checkout grants the server-defined pack", async () => {
  const { client, calls } = fakeClient({
    purchase_id: 42,
    idempotent_replay: false,
  });
  const result = await fulfillVideoCreditCheckout(client, {
    id: "cs_paid",
    mode: "payment",
    payment_status: "paid",
    currency: "jpy",
    amount_total: 1000,
    payment_intent: { id: "pi_paid" },
    metadata: {
      offer: "video_credit_pack",
      user_id: "11111111-1111-4111-8111-111111111111",
      video_credit_pack_key: "creator",
      video_credits: "999999",
    },
  });
  assertEquals(result, {
    handled: true,
    purchaseId: 42,
    idempotentReplay: false,
  });
  assertEquals(calls, [{
    name: "video_grant_credit_pack",
    args: {
      p_user_id: "11111111-1111-4111-8111-111111111111",
      p_pack_key: "creator",
      p_credits: 1200,
      p_amount_jpy: 1000,
      p_stripe_checkout_session_id: "cs_paid",
      p_stripe_payment_intent_id: "pi_paid",
    },
  }]);
});

Deno.test("unpaid checkout is handled without granting credits", async () => {
  const { client, calls } = fakeClient();
  const result = await fulfillVideoCreditCheckout(client, {
    id: "cs_unpaid",
    mode: "payment",
    payment_status: "unpaid",
    currency: "jpy",
    amount_total: 500,
    payment_intent: "pi_unpaid",
    metadata: {
      offer: "video_credit_pack",
      user_id: "11111111-1111-4111-8111-111111111111",
      video_credit_pack_key: "starter",
    },
  });
  assertEquals(result, { handled: true });
  assertEquals(calls.length, 0);
});

Deno.test("paid checkout must match the server-defined payment", async () => {
  const { client } = fakeClient();
  await assertRejects(
    () =>
      fulfillVideoCreditCheckout(client, {
        id: "cs_wrong_amount",
        mode: "payment",
        payment_status: "paid",
        currency: "jpy",
        amount_total: 1,
        payment_intent: "pi_wrong_amount",
        metadata: {
          offer: "video_credit_pack",
          user_id: "11111111-1111-4111-8111-111111111111",
          video_credit_pack_key: "starter",
        },
      }),
    Error,
    "invalid_video_credit_checkout_payment",
  );
});

Deno.test("tampered or missing video metadata fails webhook for retry", async () => {
  const { client } = fakeClient();
  await assertRejects(
    () =>
      fulfillVideoCreditCheckout(client, {
        id: "cs_bad",
        metadata: {
          offer: "video_credit_pack",
          user_id: "not-a-user-id",
          video_credit_pack_key: "starter",
        },
      }),
    Error,
    "invalid_video_credit_checkout_metadata",
  );
});

Deno.test("full refund routes to the debt-aware revoke RPC", async () => {
  const { client, calls } = fakeClient({
    matched: true,
    added_credit_debt: 200,
  });
  assertEquals(await revokeRefundedVideoCredits(client, "pi_refunded"), {
    matched: true,
    added_credit_debt: 200,
  });
  assertEquals(calls, [{
    name: "video_revoke_refunded_pack",
    args: { p_stripe_payment_intent_id: "pi_refunded" },
  }]);
});
