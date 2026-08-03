import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  activateReferralForPaidCheckout,
  ReferralActivationRpcClient,
} from "./referral_activation.ts";

class FakeReferralActivationClient implements ReferralActivationRpcClient {
  calls: Array<{ functionName: string; args: Record<string, unknown> }> = [];
  response: { data: unknown; error: { message: string } | null } = {
    data: true,
    error: null,
  };

  rpc(functionName: string, args: Record<string, unknown>) {
    this.calls.push({ functionName, args });
    return Promise.resolve(this.response);
  }
}

Deno.test("paid checkout completes a referred user's activation", async () => {
  const client = new FakeReferralActivationClient();

  assertEquals(
    await activateReferralForPaidCheckout(client, " user-123 ", " cs_123 "),
    true,
  );
  assertEquals(client.calls, [{
    functionName: "complete_referral_activation",
    args: {
      p_referred_user_id: "user-123",
      p_activation_source: "stripe_checkout_paid",
      p_stripe_checkout_session_id: "cs_123",
    },
  }]);
});

Deno.test("non-referred checkout is a successful no-op", async () => {
  const client = new FakeReferralActivationClient();
  client.response = { data: false, error: null };

  assertEquals(
    await activateReferralForPaidCheckout(client, "user-456", ""),
    false,
  );
  assertEquals(client.calls[0].args.p_stripe_checkout_session_id, null);
});

Deno.test("checkout without a user id does not call the activation RPC", async () => {
  const client = new FakeReferralActivationClient();

  assertEquals(
    await activateReferralForPaidCheckout(client, " ", "cs_789"),
    false,
  );
  assertEquals(client.calls, []);
});

Deno.test("referral activation surfaces database errors for webhook retry", async () => {
  const client = new FakeReferralActivationClient();
  client.response = {
    data: null,
    error: { message: "referral activation unavailable" },
  };

  await assertRejects(
    () => activateReferralForPaidCheckout(client, "user-789", "cs_789"),
    Error,
    "referral activation unavailable",
  );
});
