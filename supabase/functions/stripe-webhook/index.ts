import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  checkoutPaymentDecision,
  processStripeWebhookEventOnce,
} from "./event_processing.ts";
import { activateReferralForPaidCheckout } from "./referral_activation.ts";
import {
  invoiceSubscriptionId,
  subscriptionCurrentPeriodEnd,
} from "./stripe_api_compat.ts";

// .trim(): Supabase secret に紛れ込んだ前後の空白/改行を吸収 (署名検証や
// Stripe API 呼び出しがコピペ事故で失敗しないよう防御)。
const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").trim();
const SERVICE_ROLE_KEY = (Deno.env.get("SERVICE_ROLE_KEY") ?? "").trim();
const STRIPE_SECRET_KEY = (Deno.env.get("STRIPE_SECRET_KEY") ?? "").trim();
const STRIPE_WEBHOOK_SECRET = (Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "")
  .trim();

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value.trim() : fallback;
}

function normalizeTier(value: unknown): "free" | "pro" | "team" {
  const text = asString(value).toLowerCase();
  if (text === "team") return "team";
  if (text === "pro") return "pro";
  return "free";
}

function normalizeStatus(value: unknown): string {
  const text = asString(value, "active").toLowerCase();
  return [
      "active",
      "past_due",
      "canceled",
      "trialing",
      "incomplete",
    ].includes(text)
    ? text
    : "active";
}

function currentPeriodEnd(value: unknown): string | null {
  const seconds = Number(value ?? 0);
  return Number.isFinite(seconds) && seconds > 0
    ? new Date(seconds * 1000).toISOString()
    : null;
}

function asInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim() !== "") {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
  }
  return null;
}

function parseStripeSignature(header: string): {
  timestamp: string;
  signatures: string[];
} {
  const parts = header.split(",");
  let timestamp = "";
  const signatures: string[] = [];
  for (const part of parts) {
    const [key, value] = part.split("=", 2);
    if (key === "t") timestamp = value ?? "";
    if (key === "v1" && value) signatures.push(value);
  }
  return { timestamp, signatures };
}

async function hmacSha256Hex(secret: string, payload: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(payload),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function safeEqualHex(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let index = 0; index < left.length; index++) {
    diff |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return diff === 0;
}

async function verifyStripeEvent(rawBody: string, signatureHeader: string) {
  if (!STRIPE_WEBHOOK_SECRET) {
    throw new Error("STRIPE_WEBHOOK_SECRET not configured");
  }
  const { timestamp, signatures } = parseStripeSignature(signatureHeader);
  if (!timestamp || signatures.length === 0) {
    throw new Error("invalid signature header");
  }
  const expected = await hmacSha256Hex(
    STRIPE_WEBHOOK_SECRET,
    `${timestamp}.${rawBody}`,
  );
  if (!signatures.some((sig) => safeEqualHex(sig, expected))) {
    throw new Error("invalid signature");
  }
  return JSON.parse(rawBody) as Record<string, unknown>;
}

async function stripeGet(path: string): Promise<Record<string, unknown>> {
  if (!STRIPE_SECRET_KEY) throw new Error("STRIPE_SECRET_KEY not configured");
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    headers: { Authorization: `Bearer ${STRIPE_SECRET_KEY}` },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = asRecord(data.error) ?? {};
    throw new Error(
      asString(err.message) || `Stripe API failed: ${response.status}`,
    );
  }
  return asRecord(data) ?? {};
}

async function userIdForCustomer(
  admin: SupabaseClient,
  customerId: string,
): Promise<string> {
  const { data, error } = await admin
    .from("billing_subscriptions")
    .select("user_id")
    .eq("stripe_customer_id", customerId)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return asString(asRecord(data)?.user_id);
}

async function upsertSubscriptionFromStripe(
  admin: SupabaseClient,
  subscription: Record<string, unknown>,
  fallbackUserId = "",
): Promise<void> {
  const metadata = asRecord(subscription.metadata) ?? {};
  const customerId = asString(subscription.customer);
  const userId = asString(metadata.user_id) ||
    fallbackUserId ||
    await userIdForCustomer(admin, customerId);
  if (!userId || !customerId) return;

  const { error } = await admin.from("billing_subscriptions").upsert({
    user_id: userId,
    stripe_customer_id: customerId,
    stripe_subscription_id: asString(subscription.id) || null,
    tier: normalizeTier(metadata.tier),
    status: normalizeStatus(subscription.status),
    current_period_end: currentPeriodEnd(
      subscriptionCurrentPeriodEnd(subscription),
    ),
    cancel_at_period_end: subscription.cancel_at_period_end === true,
    metadata: {
      stripe_event_source: "stripe-webhook",
      stripe_subscription_metadata: metadata,
      latest_invoice: asString(subscription.latest_invoice),
    },
  }, { onConflict: "user_id" });
  if (error) throw new Error(error.message);
}

const SUPPORTER_ATTRIBUTION_FIELDS = [
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_content",
  "experiment_key",
  "variant",
  "source_log_id",
  "landing_touchpoint",
];

async function recordSupporterCheckout(
  admin: SupabaseClient,
  session: Record<string, unknown>,
  metadata: Record<string, unknown>,
): Promise<void> {
  const sessionId = asString(session.id);
  if (!sessionId) return;

  const { data: existing, error: existingError } = await admin
    .from("hub_data")
    .select("id")
    .eq("source", "stripe_supporter_payment")
    .filter("metadata->>stripe_checkout_session_id", "eq", sessionId)
    .maybeSingle();
  if (existingError) throw new Error(existingError.message);
  if (existing) return;

  const customerDetails = asRecord(session.customer_details) ?? {};
  const attribution: Record<string, string> = {};
  for (const field of SUPPORTER_ATTRIBUTION_FIELDS) {
    const value = asString(metadata[field]);
    if (value) attribution[field] = value;
  }

  const amountTotal = asInteger(session.amount_total);
  const amountJpy = asInteger(metadata.amount_jpy) ?? amountTotal;
  const { error } = await admin.from("hub_data").insert({
    source: "stripe_supporter_payment",
    metadata: {
      stripe_event_source: "checkout.session.completed",
      stripe_checkout_session_id: sessionId,
      stripe_payment_intent_id: asString(session.payment_intent) || null,
      stripe_customer_id: asString(session.customer) || null,
      customer_email: asString(customerDetails.email) ||
        asString(session.customer_email) ||
        null,
      amount_total: amountTotal,
      amount_jpy: amountJpy,
      currency: asString(session.currency).toLowerCase() || "jpy",
      payment_status: asString(session.payment_status),
      mode: asString(session.mode),
      offer: asString(metadata.offer),
      milestone_code: asString(metadata.milestone_code),
      recorded_at: new Date().toISOString(),
      ...attribution,
    },
  });
  if (error) throw new Error(error.message);
}

/**
 * 買い切り商品の購入を記録する (2026-07-28 追加)。
 *
 * この関数が作る status='paid' の行が、そのままダウンロード権利になる
 * (shop-download はこの行だけを見る)。
 *
 * 冪等性: Stripe は webhook を再送するため、同じ checkout session が複数回
 * 届きうる。shop_purchases.stripe_checkout_session_id の unique 制約に
 * onConflict で乗せることで、再送されても行が増えないようにする。
 * 「支払いは1回なのに購入が2件」は売上集計と返金対応の両方を壊す。
 *
 * 未払いの扱い: payment_status が 'paid' 以外 (銀行振込など後日確定するもの) の
 * ときは pending で作る。ここで無条件に paid にすると、入金前に配信されてしまう。
 */
async function recordShopPurchase(
  admin: SupabaseClient,
  session: Record<string, unknown>,
  metadata: Record<string, unknown>,
): Promise<void> {
  const sessionId = asString(session.id);
  const userId = asString(metadata.user_id);
  const productId = asString(metadata.shop_product_id);
  // どれか欠けると「誰の・何の」購入か確定できない。黙って捨てず記録に残す。
  if (!sessionId || !userId || !productId) {
    console.error(
      "[stripe-webhook] shop purchase missing identity",
      JSON.stringify({ sessionId, userId, productId }),
    );
    return;
  }

  const paid = asString(session.payment_status) === "paid";
  const amount = Number(session.amount_total ?? 0);

  const { error } = await admin.from("shop_purchases").upsert({
    user_id: userId,
    product_id: productId,
    stripe_checkout_session_id: sessionId,
    stripe_payment_intent_id: asString(session.payment_intent) || null,
    amount_jpy: Number.isFinite(amount) ? amount : 0,
    currency: asString(session.currency, "jpy"),
    status: paid ? "paid" : "pending",
    purchased_at: paid ? new Date().toISOString() : null,
  }, { onConflict: "stripe_checkout_session_id" });
  if (error) throw new Error(error.message);
}

async function handleCheckoutCompleted(
  admin: SupabaseClient,
  session: Record<string, unknown>,
): Promise<void> {
  const metadata = asRecord(session.metadata) ?? {};
  if (
    asString(metadata.offer) === "founding_supporter" ||
    asString(metadata.milestone_code) === "first-yen-revenue"
  ) {
    await recordSupporterCheckout(admin, session, metadata);
    return;
  }

  // 買い切り商品 (2026-07-28 追加)。shop-checkout が metadata に載せた商品IDで判別する。
  if (asString(metadata.shop_product_id)) {
    await recordShopPurchase(admin, session, metadata);
    return;
  }

  const userId = asString(metadata.user_id);
  const customerId = asString(session.customer);
  const subscriptionId = asString(session.subscription);
  if (!userId || !customerId) return;

  const { error } = await admin.from("billing_subscriptions").upsert({
    user_id: userId,
    stripe_customer_id: customerId,
    stripe_subscription_id: subscriptionId || null,
    tier: normalizeTier(metadata.tier || "pro"),
    status: "active",
    metadata: {
      stripe_event_source: "checkout.session.completed",
      stripe_checkout_session_id: asString(session.id),
      stripe_checkout_metadata: metadata,
    },
  }, { onConflict: "user_id" });
  if (error) throw new Error(error.message);

  if (subscriptionId) {
    const subscription = await stripeGet(`/subscriptions/${subscriptionId}`);
    await upsertSubscriptionFromStripe(admin, subscription, userId);
  }

  await activateReferralForPaidCheckout(
    admin,
    userId,
    asString(session.id),
  );
}

async function markPastDue(
  admin: SupabaseClient,
  invoice: Record<string, unknown>,
): Promise<void> {
  const subscriptionId = invoiceSubscriptionId(invoice);
  const customerId = asString(invoice.customer);
  let userId = "";
  if (customerId) userId = await userIdForCustomer(admin, customerId);
  if (!userId) return;

  const { error } = await admin
    .from("billing_subscriptions")
    .update({
      status: "past_due",
      stripe_subscription_id: subscriptionId || undefined,
      metadata: {
        stripe_event_source: "invoice.payment_failed",
        invoice_id: asString(invoice.id),
      },
    })
    .eq("user_id", userId);
  if (error) throw new Error(error.message);
}

serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method not allowed" }, 405);
  try {
    const signature = req.headers.get("stripe-signature") ?? "";
    if (!signature) return json({ error: "missing stripe-signature" }, 400);
    const rawBody = await req.text();
    const event = await verifyStripeEvent(rawBody, signature);
    const eventId = asString(event.id);
    const type = asString(event.type);
    if (!eventId || !type) throw new Error("invalid Stripe event envelope");
    const data = asRecord(asRecord(event.data)?.object) ?? {};
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const processed = await processStripeWebhookEventOnce(
      admin,
      eventId,
      type,
      async () => {
        let result: Record<string, unknown> = {};

        if (
          type === "checkout.session.completed" ||
          type === "checkout.session.async_payment_succeeded"
        ) {
          const decision = checkoutPaymentDecision(data);
          if (decision.shouldFulfill) {
            await handleCheckoutCompleted(admin, data);
          } else {
            result = {
              skipped: true,
              reason: decision.reason,
              payment_status: decision.paymentStatus,
            };
          }
        } else if (
          type === "customer.subscription.created" ||
          type === "customer.subscription.updated" ||
          type === "customer.subscription.deleted"
        ) {
          await upsertSubscriptionFromStripe(admin, data);
        } else if (type === "invoice.payment_failed") {
          await markPastDue(admin, data);
        }

        return result;
      },
    );

    if (processed.duplicate) {
      return json({ received: true, duplicate: true, event_id: eventId });
    }
    return json({ received: true, event_id: eventId, ...processed.value });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({
      error: message,
    }, 400);
  }
});
