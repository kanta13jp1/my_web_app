import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SERVICE_ROLE_KEY") ?? "";
const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";

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
    current_period_end: currentPeriodEnd(subscription.current_period_end),
    cancel_at_period_end: subscription.cancel_at_period_end === true,
    metadata: {
      stripe_event_source: "stripe-webhook",
      stripe_subscription_metadata: metadata,
      latest_invoice: asString(subscription.latest_invoice),
    },
  }, { onConflict: "user_id" });
  if (error) throw new Error(error.message);
}

async function handleCheckoutCompleted(
  admin: SupabaseClient,
  session: Record<string, unknown>,
): Promise<void> {
  const metadata = asRecord(session.metadata) ?? {};
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
    },
  }, { onConflict: "user_id" });
  if (error) throw new Error(error.message);

  if (subscriptionId) {
    const subscription = await stripeGet(`/subscriptions/${subscriptionId}`);
    await upsertSubscriptionFromStripe(admin, subscription, userId);
  }
}

async function markPastDue(
  admin: SupabaseClient,
  invoice: Record<string, unknown>,
): Promise<void> {
  const subscriptionId = asString(invoice.subscription);
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
    const type = asString(event.type);
    const data = asRecord(asRecord(event.data)?.object) ?? {};
    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    if (type === "checkout.session.completed") {
      await handleCheckoutCompleted(admin, data);
    } else if (
      type === "customer.subscription.created" ||
      type === "customer.subscription.updated" ||
      type === "customer.subscription.deleted"
    ) {
      await upsertSubscriptionFromStripe(admin, data);
    } else if (type === "invoice.payment_failed") {
      await markPastDue(admin, data);
    }

    return json({ received: true });
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : String(error),
    }, 400);
  }
});
