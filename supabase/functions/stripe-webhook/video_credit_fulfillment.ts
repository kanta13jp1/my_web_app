import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { videoCreditPack } from "../_shared/video_credit_packs.ts";

export type VideoCreditFulfillment = {
  handled: boolean;
  purchaseId?: number;
  idempotentReplay?: boolean;
};

export async function fulfillVideoCreditCheckout(
  admin: SupabaseClient,
  session: Record<string, unknown>,
): Promise<VideoCreditFulfillment> {
  const metadata = asRecord(session.metadata);
  if (asString(metadata.offer) !== "video_credit_pack") {
    return { handled: false };
  }

  const userId = asString(metadata.user_id);
  const pack = videoCreditPack(metadata.video_credit_pack_key);
  const sessionId = asString(session.id);
  const paymentIntentId = stripeObjectId(session.payment_intent);
  if (!isUuid(userId) || !pack || !sessionId) {
    throw new Error("invalid_video_credit_checkout_metadata");
  }
  if (asString(session.payment_status) !== "paid") {
    return { handled: true };
  }
  if (
    asString(session.mode) !== "payment" ||
    asString(session.currency).toLowerCase() !== "jpy" ||
    asInteger(session.amount_total) !== pack.amountJpy ||
    !paymentIntentId
  ) {
    throw new Error("invalid_video_credit_checkout_payment");
  }

  const { data, error } = await admin.rpc("video_grant_credit_pack", {
    p_user_id: userId,
    p_pack_key: pack.key,
    p_credits: pack.credits,
    p_amount_jpy: pack.amountJpy,
    p_stripe_checkout_session_id: sessionId,
    p_stripe_payment_intent_id: paymentIntentId,
  });
  if (error) throw new Error(error.message);
  const result = asRecord(data);
  return {
    handled: true,
    purchaseId: asInteger(result.purchase_id) ?? undefined,
    idempotentReplay: result.idempotent_replay === true,
  };
}

export async function revokeRefundedVideoCredits(
  admin: SupabaseClient,
  paymentIntentId: string,
): Promise<Record<string, unknown>> {
  if (!paymentIntentId) return { matched: false };
  const { data, error } = await admin.rpc("video_revoke_refunded_pack", {
    p_stripe_payment_intent_id: paymentIntentId,
  });
  if (error) throw new Error(error.message);
  return asRecord(data);
}

function stripeObjectId(value: unknown): string {
  if (typeof value === "string") return value.trim();
  return asString(asRecord(value).id);
}

function asRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function asString(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asInteger(value: unknown): number | null {
  const parsed = typeof value === "number" ? value : Number(value);
  return Number.isInteger(parsed) ? parsed : null;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
