import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  fulfillReferralCreditsForPaidCheckout,
  ReferralCreditGrant,
  ReferralCreditRpcClient,
} from "./referral_credit.ts";

type RpcCall = { functionName: string; args: Record<string, unknown> };

class FakeClient implements ReferralCreditRpcClient {
  calls: RpcCall[] = [];
  grants: unknown[] = [];
  failError: { message: string } | null = null;

  rpc(functionName: string, args: Record<string, unknown>) {
    this.calls.push({ functionName, args });
    if (functionName === "claim_next_referral_credit_grant") {
      return Promise.resolve({
        data: this.grants.shift() ?? null,
        error: null,
      });
    }
    if (functionName === "fail_referral_credit_grant") {
      return Promise.resolve({
        data: this.failError === null,
        error: this.failError,
      });
    }
    return Promise.resolve({ data: true, error: null });
  }
}

function grant(
  id: number,
  role: "referrer" | "referred",
): Record<string, unknown> {
  return {
    id,
    referral_id: 91,
    beneficiary_user_id: `${role}-user`,
    beneficiary_role: role,
    stripe_idempotency_key: `referral-credit-91-${role}`,
  };
}

Deno.test("paid activation grants one Pro-month credit to both users", async () => {
  const client = new FakeClient();
  client.grants = [grant(1, "referrer"), grant(2, "referred")];
  const transactions: Array<{
    grant: ReferralCreditGrant;
    customerId: string;
    amount: number;
    currency: string;
  }> = [];

  const count = await fulfillReferralCreditsForPaidCheckout(" referred-user ", {
    client,
    loadCreditValue: () => Promise.resolve({ amount: 1200, currency: "JPY" }),
    getOrCreateCustomer: (userId) => Promise.resolve(`cus_${userId}`),
    createBalanceTransaction: (input) => {
      transactions.push(input);
      return Promise.resolve(`cbtxn_${input.grant.id}`);
    },
  });

  assertEquals(count, 2);
  assertEquals(
    transactions.map((entry) => ({
      role: entry.grant.beneficiaryRole,
      amount: entry.amount,
      currency: entry.currency,
      idempotencyKey: entry.grant.stripeIdempotencyKey,
    })),
    [
      {
        role: "referrer",
        amount: -1200,
        currency: "jpy",
        idempotencyKey: "referral-credit-91-referrer",
      },
      {
        role: "referred",
        amount: -1200,
        currency: "jpy",
        idempotencyKey: "referral-credit-91-referred",
      },
    ],
  );
  assertEquals(
    client.calls.filter((call) =>
      call.functionName === "complete_referral_credit_grant"
    ).length,
    2,
  );
});

Deno.test("already granted referral is a no-op", async () => {
  const client = new FakeClient();
  let stripeCalls = 0;
  const count = await fulfillReferralCreditsForPaidCheckout("user-1", {
    client,
    loadCreditValue: () => Promise.resolve({ amount: 1200, currency: "jpy" }),
    getOrCreateCustomer: () => Promise.resolve("cus_1"),
    createBalanceTransaction: () => {
      stripeCalls++;
      return Promise.resolve("cbtxn_1");
    },
  });

  assertEquals(count, 0);
  assertEquals(stripeCalls, 0);
});

Deno.test("Stripe failure persists a retryable grant state", async () => {
  const client = new FakeClient();
  client.grants = [grant(7, "referrer")];

  await assertRejects(
    () =>
      fulfillReferralCreditsForPaidCheckout("user-1", {
        client,
        loadCreditValue: () =>
          Promise.resolve({ amount: 1200, currency: "jpy" }),
        getOrCreateCustomer: () => Promise.resolve("cus_1"),
        createBalanceTransaction: () =>
          Promise.reject(new Error("Stripe down")),
      }),
    Error,
    "Stripe down",
  );
  assertEquals(client.calls.at(-1), {
    functionName: "fail_referral_credit_grant",
    args: { p_grant_id: 7, p_error: "Stripe down" },
  });
});
