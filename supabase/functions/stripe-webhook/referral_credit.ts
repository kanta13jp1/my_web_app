export type ReferralCreditRpcClient = {
  rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message: string } | null }>;
};

export type ReferralCreditValue = {
  amount: number;
  currency: string;
};

export type ReferralCreditGrant = {
  id: number;
  referralId: number;
  beneficiaryUserId: string;
  beneficiaryRole: "referrer" | "referred";
  stripeIdempotencyKey: string;
};

export type ReferralCreditDependencies = {
  client: ReferralCreditRpcClient;
  loadCreditValue: () => Promise<ReferralCreditValue>;
  getOrCreateCustomer: (userId: string) => Promise<string>;
  createBalanceTransaction: (input: {
    grant: ReferralCreditGrant;
    customerId: string;
    amount: number;
    currency: string;
  }) => Promise<string>;
};

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asPositiveInteger(value: unknown): number {
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : 0;
}

function parseGrant(value: unknown): ReferralCreditGrant | null {
  const row = asRecord(value);
  if (!row) return null;
  const id = asPositiveInteger(row.id);
  const referralId = asPositiveInteger(row.referral_id);
  const beneficiaryUserId = asString(row.beneficiary_user_id);
  const beneficiaryRole = asString(row.beneficiary_role);
  const stripeIdempotencyKey = asString(row.stripe_idempotency_key);
  if (
    !id ||
    !referralId ||
    !beneficiaryUserId ||
    !stripeIdempotencyKey ||
    (beneficiaryRole !== "referrer" && beneficiaryRole !== "referred")
  ) {
    throw new Error("Malformed referral credit grant");
  }
  return {
    id,
    referralId,
    beneficiaryUserId,
    beneficiaryRole,
    stripeIdempotencyKey,
  };
}

function normalizeCreditValue(value: ReferralCreditValue): ReferralCreditValue {
  const amount = asPositiveInteger(value.amount);
  const currency = asString(value.currency).toLowerCase();
  if (!amount || !/^[a-z]{3}$/.test(currency)) {
    throw new Error("Stripe Pro price has an invalid referral credit value");
  }
  return { amount, currency };
}

async function markGrantFailed(
  client: ReferralCreditRpcClient,
  grantId: number,
  error: unknown,
): Promise<void> {
  const message = error instanceof Error ? error.message : String(error);
  const { error: rpcError } = await client.rpc("fail_referral_credit_grant", {
    p_grant_id: grantId,
    p_error: message,
  });
  if (rpcError) {
    throw new Error(
      `${message}; failed to persist retry state: ${rpcError.message}`,
    );
  }
}

/// Fulfills the two give-get credits created by referral activation.
///
/// The database claim is atomic and each Stripe request uses a stable,
/// grant-specific idempotency key. A completed grant is never claimable again.
export async function fulfillReferralCreditsForPaidCheckout(
  referredUserId: string,
  dependencies: ReferralCreditDependencies,
): Promise<number> {
  const userId = referredUserId.trim();
  if (!userId) return 0;

  let creditValue: ReferralCreditValue | null = null;
  let grantedCount = 0;
  for (let index = 0; index < 2; index++) {
    const { data, error } = await dependencies.client.rpc(
      "claim_next_referral_credit_grant",
      { p_referred_user_id: userId },
    );
    if (error) throw new Error(error.message);
    const grant = parseGrant(data);
    if (!grant) break;

    try {
      creditValue ??= normalizeCreditValue(
        await dependencies.loadCreditValue(),
      );
      const customerId = (
        await dependencies.getOrCreateCustomer(grant.beneficiaryUserId)
      ).trim();
      if (!customerId) throw new Error("Stripe customer id missing");

      const transactionId = (
        await dependencies.createBalanceTransaction({
          grant,
          customerId,
          amount: -creditValue.amount,
          currency: creditValue.currency,
        })
      ).trim();
      if (!transactionId) {
        throw new Error("Stripe balance transaction id missing");
      }

      const completion = await dependencies.client.rpc(
        "complete_referral_credit_grant",
        {
          p_grant_id: grant.id,
          p_stripe_customer_id: customerId,
          p_stripe_balance_transaction_id: transactionId,
          p_credit_amount: creditValue.amount,
          p_currency: creditValue.currency,
        },
      );
      if (completion.error) throw new Error(completion.error.message);
      if (completion.data !== true) {
        throw new Error("Referral credit grant was not finalized");
      }
      grantedCount++;
    } catch (error) {
      await markGrantFailed(dependencies.client, grant.id, error);
      throw error;
    }
  }
  return grantedCount;
}
