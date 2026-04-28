---
title: "Supabase × Stripe — Implement Subscription Billing with Edge Functions"
tags: supabase,ai,indiedev,automation
published: true
---

# Supabase × Stripe — Implement Subscription Billing with Edge Functions

Build a monthly subscription system with Stripe and Supabase Edge Functions.

## Architecture Overview

```
Flutter → Supabase EF (create-checkout) → Stripe Checkout
Stripe Webhook → Supabase EF (stripe-webhook) → DB update
Flutter → Supabase DB (read subscription status)
```

## Create a Checkout Session

```typescript
// supabase/functions/create-checkout/index.ts
import Stripe from "npm:stripe";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!);

Deno.serve(async (req) => {
  const { userId, priceId } = await req.json();

  // Get existing Stripe Customer ID (or create one)
  const { data: profile } = await supabase
    .from("profiles")
    .select("stripe_customer_id, email")
    .eq("id", userId)
    .single();

  let customerId = profile.stripe_customer_id;
  if (!customerId) {
    const customer = await stripe.customers.create({ email: profile.email });
    customerId = customer.id;
    await supabase.from("profiles").update({ stripe_customer_id: customerId }).eq("id", userId);
  }

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    payment_method_types: ["card"],
    line_items: [{ price: priceId, quantity: 1 }],
    mode: "subscription",
    success_url: `${Deno.env.get("APP_URL")}/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${Deno.env.get("APP_URL")}/pricing`,
    metadata: { user_id: userId },
  });

  return new Response(JSON.stringify({ url: session.url }));
});
```

## Update DB via Webhook

```typescript
// supabase/functions/stripe-webhook/index.ts
Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature")!;
  const body = await req.text();

  const event = stripe.webhooks.constructEvent(
    body,
    sig,
    Deno.env.get("STRIPE_WEBHOOK_SECRET")!
  );

  switch (event.type) {
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const sub = event.data.object as Stripe.Subscription;
      const userId = sub.metadata.user_id;
      await supabase.from("subscriptions").upsert({
        user_id: userId,
        stripe_subscription_id: sub.id,
        status: sub.status,           // active / past_due / canceled
        current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
        plan: sub.items.data[0].price.lookup_key,
      });
      break;
    }
    case "customer.subscription.deleted": {
      const sub = event.data.object as Stripe.Subscription;
      await supabase
        .from("subscriptions")
        .update({ status: "canceled" })
        .eq("stripe_subscription_id", sub.id);
      break;
    }
  }

  return new Response("ok");
});
```

## Open Checkout from Flutter

```dart
Future<void> openCheckout(String priceId) async {
  final res = await supabase.functions.invoke(
    'create-checkout',
    body: {'userId': supabase.auth.currentUser!.id, 'priceId': priceId},
  );

  final url = (res.data as Map)['url'] as String;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
```

## Summary

```
Checkout    → EF creates Stripe session → Flutter opens the URL
Webhook     → Stripe → EF → update subscriptions table
Status      → Flutter reads subscriptions table directly (protected by RLS)
Security    → STRIPE_WEBHOOK_SECRET signature verification is mandatory
```

Skipping webhook signature verification lets attackers spoof events and falsify billing status. Always verify.
