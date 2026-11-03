import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import {
  chargeRefundDecision,
  checkoutPaymentDecision,
  processStripeWebhookEventOnce,
} from "./event_processing.ts";
import { activateReferralForPaidCheckout } from "./referral_activation.ts";
import {
  fulfillReferralCreditsForPaidCheckout,
  ReferralCreditGrant,
} from "./referral_credit.ts";
import {
  invoiceSubscriptionId,
  subscriptionCurrentPeriodEnd,
} from "./stripe_api_compat.ts";
import { verifyStripeEvent } from "./stripe_signature.ts";
import {
  isExternalRevenueCandidate,
  normalizeSupporterBuyerContext,
} from "../_shared/supporter_buyer.ts";
import {
  fulfillVideoCreditCheckout,
  revokeRefundedVideoCredits,
} from "./video_credit_fulfillment.ts";

// .trim(): Supabase secret に紛れ込んだ前後の空白/改行を吸収 (署名検証や
// Stripe API 呼び出しがコピペ事故で失敗しないよう防御)。
const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").trim();
const SERVICE_ROLE_KEY = (Deno.env.get("SERVICE_ROLE_KEY") ?? "").trim();
const STRIPE_SECRET_KEY = (Deno.env.get("STRIPE_SECRET_KEY") ?? "").trim();
const STRIPE_WEBHOOK_SECRET = (Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "")
  .trim();
const STRIPE_API_VERSION = "2026-06-24.dahlia";

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

async function stripeGet(path: string): Promise<Record<string, unknown>> {
  if (!STRIPE_SECRET_KEY) throw new Error("STRIPE_SECRET_KEY not configured");
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    headers: {
      Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
      "Stripe-Version": STRIPE_API_VERSION,
    },
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

async function stripePostForm(
  path: string,
  params: Record<string, string>,
  idempotencyKey?: string,
): Promise<Record<string, unknown>> {
  if (!STRIPE_SECRET_KEY) throw new Error("STRIPE_SECRET_KEY not configured");
  const headers: Record<string, string> = {
    Authorization: `Bearer ${STRIPE_SECRET_KEY}`,
    "Content-Type": "application/x-www-form-urlencoded",
    "Stripe-Version": STRIPE_API_VERSION,
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  const response = await fetch(`https://api.stripe.com/v1${path}`, {
    method: "POST",
    headers,
    body: new URLSearchParams(params),
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

function stripeProPriceId(): string {
  return (Deno.env.get("STRIPE_PRO_PRICE_ID") ??
    Deno.env.get("STRIPE_PRICE_PRO") ?? "").trim();
}

async function loadReferralCreditValue(): Promise<{
  amount: number;
  currency: string;
}> {
  const priceId = stripeProPriceId();
  if (!priceId) throw new Error("STRIPE_PRO_PRICE_ID not configured");
  const price = await stripeGet(`/prices/${encodeURIComponent(priceId)}`);
  const amount = asInteger(price.unit_amount) ?? 0;
  const currency = asString(price.currency).toLowerCase();
  const recurring = asRecord(price.recurring);
  if (
    amount <= 0 ||
    !/^[a-z]{3}$/.test(currency) ||
    asString(recurring?.interval) !== "month" ||
    (asInteger(recurring?.interval_count) ?? 1) !== 1
  ) {
    throw new Error("Stripe Pro price must be a one-month recurring price");
  }
  return { amount, currency };
}

async function getOrCreateReferralStripeCustomer(
  admin: SupabaseClient,
  userId: string,
): Promise<string> {
  const { data: currentData, error: currentError } = await admin
    .from("billing_subscriptions")
    .select("stripe_customer_id, tier, status, metadata")
    .eq("user_id", userId)
    .maybeSingle();
  if (currentError) throw new Error(currentError.message);
  const current = asRecord(currentData) ?? {};
  const existingCustomerId = asString(current.stripe_customer_id);
  if (existingCustomerId) return existingCustomerId;

  const { data: userData, error: userError } = await admin.auth.admin
    .getUserById(userId);
  if (userError) throw new Error(userError.message);
  const customer = await stripePostForm("/customers", {
    email: userData.user?.email ?? "",
    "metadata[user_id]": userId,
    "metadata[source]": "referral_credit",
  }, `referral-customer-${userId}`);
  const customerId = asString(customer.id);
  if (!customerId) throw new Error("Stripe customer id missing");

  const { error: upsertError } = await admin.from("billing_subscriptions")
    .upsert({
      user_id: userId,
      stripe_customer_id: customerId,
      tier: asString(current.tier, "free"),
      status: asString(current.status, "active"),
      metadata: {
        ...(asRecord(current.metadata) ?? {}),
        referral_credit_customer_created: true,
      },
    }, { onConflict: "user_id" });
  if (upsertError) throw new Error(upsertError.message);
  return customerId;
}

async function createReferralBalanceTransaction(input: {
  grant: ReferralCreditGrant;
  customerId: string;
  amount: number;
  currency: string;
}): Promise<string> {
  const transaction = await stripePostForm(
    `/customers/${encodeURIComponent(input.customerId)}/balance_transactions`,
    {
      amount: String(input.amount),
      currency: input.currency,
      description: "紹介特典: Pro 1か月分クレジット",
      "metadata[referral_credit_grant_id]": String(input.grant.id),
      "metadata[referral_id]": String(input.grant.referralId),
      "metadata[beneficiary_role]": input.grant.beneficiaryRole,
    },
    input.grant.stripeIdempotencyKey,
  );
  return asString(transaction.id);
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
  const buyerContext = normalizeSupporterBuyerContext(
    metadata.auth_user_id,
    metadata.buyer_classification,
  );
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
      auth_user_id: buyerContext.authUserId,
      buyer_classification: buyerContext.classification,
      external_revenue_candidate: isExternalRevenueCandidate(buyerContext),
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

  // funnel の最終段 (2026-07-29 追加)。入金を確認したここでだけ書く。
  // クライアントの「買えました」を信じると、金銭の絡む段だけ検証できない
  // 数字になるため。記録の失敗で購入処理を巻き戻さない (計測は本体ではない)。
  if (paid) await recordPurchaseFunnelStage(admin, metadata);
}

/**
 * 購入完了を funnel へ記録する (2026-07-29 追加)。
 *
 * visitor_id は shop-checkout が Stripe の metadata に載せて運んでいる。
 * 無い場合 (metadata を持たない古いセッション等) は**何もしない**。
 * 適当な値で埋めると、閲覧から購入までの経路が繋がっていない行が混ざり、
 * 到達人数の集計が壊れる。
 */
async function recordPurchaseFunnelStage(
  admin: SupabaseClient,
  metadata: Record<string, unknown>,
): Promise<void> {
  const visitorId = asString(metadata.shop_visitor_id);
  const productId = asString(metadata.shop_product_id);
  if (!visitorId || !productId) return;

  const source = asString(metadata.shop_source) || "direct";
  const { error } = await admin.from("shop_funnel_events").upsert({
    visitor_id: visitorId,
    product_id: productId,
    stage: "purchase_complete",
    source,
    auth_user_id: asString(metadata.user_id) || null,
  }, {
    onConflict: "visitor_id,product_id,source,stage",
    ignoreDuplicates: true,
  });
  if (error) {
    console.error("[stripe-webhook] funnel record failed:", error.message);
  }
}

async function handleCheckoutCompleted(
  admin: SupabaseClient,
  session: Record<string, unknown>,
): Promise<void> {
  const videoCreditFulfillment = await fulfillVideoCreditCheckout(
    admin,
    session,
  );
  if (videoCreditFulfillment.handled) return;

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

  const hasReferral = await activateReferralForPaidCheckout(
    admin,
    userId,
    asString(session.id),
  );
  if (hasReferral) {
    await fulfillReferralCreditsForPaidCheckout(userId, {
      client: admin,
      loadCreditValue: loadReferralCreditValue,
      getOrCreateCustomer: (beneficiaryUserId) =>
        getOrCreateReferralStripeCustomer(admin, beneficiaryUserId),
      createBalanceTransaction: createReferralBalanceTransaction,
    });
  }
}

async function handleChargeRefunded(
  admin: SupabaseClient,
  charge: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const decision = chargeRefundDecision(charge);
  const shop = await markShopPurchaseRefunded(admin, charge);
  if (!decision.shouldRevoke || !decision.paymentIntentId) {
    return { ...shop, video_credit_refund: { matched: false } };
  }
  const videoCreditRefund = await revokeRefundedVideoCredits(
    admin,
    decision.paymentIntentId,
  );
  return { ...shop, video_credit_refund: videoCreditRefund };
}

/**
 * 返金を受けてダウンロード権利を失効させる (2026-07-30 追加)。
 *
 * `shop_purchases` の status='paid' の行がそのまま権利なので (shop-download は
 * この行だけを見る)、返金後もその行が残っていると**返金したのに落とせる**状態が
 * 続く。これまでは手動で status を更新する必要があった。
 *
 * 対象の特定は `stripe_payment_intent_id`。サブスクの請求に対する返金でも同じ
 * `charge.refunded` が届くが、その payment intent に一致する購入行は無いので
 * 0 件更新で素通りする (エラーにしない)。ただし「0 件だった」ことは必ず残す —
 * 本当に権利を消せていない取りこぼしと区別できなくなるため。
 *
 * 冪等性: 同じ payment intent に何度届いても status='refunded' を書くだけなので
 * 結果は変わらない。`neq` で既に refunded の行を除くのは、updated_at を
 * 無意味に動かして「いつ返金処理したか」を分からなくしないため。
 */
async function markShopPurchaseRefunded(
  admin: SupabaseClient,
  charge: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const decision = chargeRefundDecision(charge);
  const chargeId = asString(charge.id);

  if (!decision.shouldRevoke) {
    console.warn(
      "[stripe-webhook] refund did not revoke shop access",
      JSON.stringify({
        charge_id: chargeId,
        reason: decision.reason,
        amount: decision.amount,
        amount_refunded: decision.amountRefunded,
      }),
    );
    return { refund_revoked: 0, reason: decision.reason };
  }

  const { data, error } = await admin
    .from("shop_purchases")
    .update({ status: "refunded" })
    .eq("stripe_payment_intent_id", decision.paymentIntentId)
    .neq("status", "refunded")
    .select("id");
  if (error) throw new Error(error.message);

  const revoked = Array.isArray(data) ? data.length : 0;
  if (revoked === 0) {
    // サブスク返金なら正常。買い切りの返金でここに来たら紐付けが壊れている。
    console.warn(
      "[stripe-webhook] refund matched no shop purchase",
      JSON.stringify({
        charge_id: chargeId,
        payment_intent: decision.paymentIntentId,
      }),
    );
  }
  return { refund_revoked: revoked };
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
    const event = await verifyStripeEvent(
      rawBody,
      signature,
      STRIPE_WEBHOOK_SECRET,
    );
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
        } else if (type === "charge.refunded") {
          result = await handleChargeRefunded(admin, data);
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
