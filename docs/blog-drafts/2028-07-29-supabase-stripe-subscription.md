---
title: "Supabase × Stripe — サブスクリプション決済を Edge Function で実装する"
tags: supabase,AI,個人開発,automation
published: true
---

# Supabase × Stripe — サブスクリプション決済を Edge Function で実装する

月額課金の仕組みを Stripe + Supabase Edge Function で構築する。

## 全体アーキテクチャ

```
Flutter → Supabase EF (create-checkout) → Stripe Checkout
Stripe Webhook → Supabase EF (stripe-webhook) → DB更新
Flutter → Supabase DB (subscription ステータス確認)
```

## Checkout セッション作成

```typescript
// supabase/functions/create-checkout/index.ts
import Stripe from "npm:stripe";

const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY")!);

Deno.serve(async (req) => {
  const { userId, priceId } = await req.json();

  // 既存 Stripe Customer ID を取得 (なければ作成)
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

## Webhook でサブスク状態を DB 更新

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

## Flutter から Checkout を開く

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

## まとめ

```
Checkout     → EF で Stripe セッション作成 → Flutter で URL を開く
Webhook      → Stripe → EF → subscriptions テーブル更新
状態確認     → Flutter が subscriptions テーブルを直接参照 (RLS で保護)
セキュリティ → STRIPE_WEBHOOK_SECRET で署名検証必須
```

Webhook の署名検証をスキップすると偽リクエストで課金ステータスを改ざんできる。必ず実装する。
