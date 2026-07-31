import { referenceId } from "./stripe_api_compat.ts";

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

export type ChargeRefundDecision = {
  shouldRevoke: boolean;
  paymentIntentId: string;
  amount: number;
  amountRefunded: number;
  reason: "missing_payment_intent" | "partial_refund" | null;
};

export type StripeEventProcessingResult<T> =
  | { duplicate: true }
  | { duplicate: false; value: T };

function normalizedString(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function integerOrZero(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : 0;
  }
  return 0;
}

/**
 * `charge.refunded` を受けて、ダウンロード権利を失効させるべきかを判定する
 * (2026-07-30 追加)。
 *
 * `charge.refunded` は**部分返金でも届く**。部分返金で権利を消すと、
 * 支払った分が残っている利用者から取り上げてしまうので、失効させるのは
 * 全額返金のときだけにする。
 *
 * 全額判定を 2 つの根拠の **OR** にしているのは意図的。`charge.refunded`
 * (= 全額返金のときだけ true) と `amount_refunded >= amount` はどちらも
 * 単独で全額返金を示すが、片方のフィールドが API バージョンで移動しても
 * **「返金済みなのに権利が残る」側へ倒れない**ようにしたい。この誤りの向きは
 * 非対称で、取りこぼし (返金者が商品を持ち続ける) の方が、部分返金を
 * 全額と誤判定する場合より損害が大きい。
 */
export function chargeRefundDecision(
  charge: Record<string, unknown>,
): ChargeRefundDecision {
  // expand されて object になっている場合も ID を拾う。
  const paymentIntentId = referenceId(charge.payment_intent);
  const amount = integerOrZero(charge.amount);
  const amountRefunded = integerOrZero(charge.amount_refunded);

  // payment intent が無いと、どの購入行なのか特定できない。
  if (!paymentIntentId) {
    return {
      shouldRevoke: false,
      paymentIntentId: "",
      amount,
      amountRefunded,
      reason: "missing_payment_intent",
    };
  }

  const fullyRefunded = charge.refunded === true ||
    (amount > 0 && amountRefunded >= amount);
  if (!fullyRefunded) {
    return {
      shouldRevoke: false,
      paymentIntentId,
      amount,
      amountRefunded,
      reason: "partial_refund",
    };
  }

  return {
    shouldRevoke: true,
    paymentIntentId,
    amount,
    amountRefunded,
    reason: null,
  };
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
