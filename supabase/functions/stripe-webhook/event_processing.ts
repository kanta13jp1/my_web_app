export type RpcError = { message: string } | null;

export type StripeWebhookRpcClient = {
  rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: RpcError }>;
};

export type CheckoutPaymentDecision = {
  shouldFulfill: boolean;
  paymentStatus: string;
  reason: "checkout_not_paid" | null;
};

export type StripeEventProcessingResult<T> =
  | { duplicate: true }
  | { duplicate: false; value: T };

function normalizedString(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

export function checkoutPaymentDecision(
  session: Record<string, unknown>,
): CheckoutPaymentDecision {
  const paymentStatus = normalizedString(session.payment_status);
  if (paymentStatus === "paid") {
    return { shouldFulfill: true, paymentStatus, reason: null };
  }
  return {
    shouldFulfill: false,
    paymentStatus,
    reason: "checkout_not_paid",
  };
}

async function callEventRpc(
  client: StripeWebhookRpcClient,
  functionName: string,
  args: Record<string, unknown>,
): Promise<unknown> {
  const { data, error } = await client.rpc(functionName, args);
  if (error) throw new Error(error.message);
  return data;
}

export async function claimStripeWebhookEvent(
  client: StripeWebhookRpcClient,
  eventId: string,
  eventType: string,
): Promise<boolean> {
  const data = await callEventRpc(client, "claim_stripe_webhook_event", {
    p_event_id: eventId,
    p_event_type: eventType,
  });
  return data === true;
}

export async function completeStripeWebhookEvent(
  client: StripeWebhookRpcClient,
  eventId: string,
): Promise<void> {
  await callEventRpc(client, "complete_stripe_webhook_event", {
    p_event_id: eventId,
  });
}

export async function failStripeWebhookEvent(
  client: StripeWebhookRpcClient,
  eventId: string,
  errorMessage: string,
): Promise<void> {
  await callEventRpc(client, "fail_stripe_webhook_event", {
    p_event_id: eventId,
    p_error: errorMessage.slice(0, 4000),
  });
}

export async function processStripeWebhookEventOnce<T>(
  client: StripeWebhookRpcClient,
  eventId: string,
  eventType: string,
  process: () => Promise<T>,
): Promise<StripeEventProcessingResult<T>> {
  const claimed = await claimStripeWebhookEvent(client, eventId, eventType);
  if (!claimed) return { duplicate: true };

  try {
    const value = await process();
    await completeStripeWebhookEvent(client, eventId);
    return { duplicate: false, value };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    try {
      await failStripeWebhookEvent(client, eventId, message);
    } catch (ledgerError) {
      console.error("Failed to mark Stripe event as failed", ledgerError);
    }
    throw error;
  }
}
