export type ReferralActivationRpcClient = {
  rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message: string } | null }>;
};

export async function activateReferralForPaidCheckout(
  client: ReferralActivationRpcClient,
  referredUserId: string,
  stripeCheckoutSessionId: string,
): Promise<boolean> {
  const userId = referredUserId.trim();
  if (!userId) return false;

  const sessionId = stripeCheckoutSessionId.trim();
  const { data, error } = await client.rpc("complete_referral_activation", {
    p_referred_user_id: userId,
    p_activation_source: "stripe_checkout_paid",
    p_stripe_checkout_session_id: sessionId || null,
  });
  if (error) throw new Error(error.message);
  return data === true;
}
