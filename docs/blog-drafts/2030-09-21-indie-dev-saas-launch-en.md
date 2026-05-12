---
title: "Indie Dev SaaS Launch — Pricing Strategy, Stripe Integration, and Freemium-to-Paid Design"
tags: indiedev,buildinpublic,flutter,programming
published: true
---

Monetization is where most indie SaaS apps die. Not because the product is bad, but because the pricing is wrong, the freemium tier is too generous, or the upgrade path is invisible. This guide covers the full stack: value-based pricing principles, freemium architecture, Stripe + Supabase implementation, and conversion optimization.

## Pricing Principle: Charge for Value, Not Features

The classic mistake: pricing based on features ("get 5 exports per month for $5"). The right framing: what outcome does your tool deliver?

| Feature-based (weak) | Value-based (strong) |
|---------------------|---------------------|
| 5GB storage → $5 | Save 10 hours/month → $29 |
| Export to CSV → $10 | Automated reporting → $49 |
| API access → $20 | Eliminate manual data entry → $99 |

### Van Westendorp Price Sensitivity Test

Interview 20-30 target users before launch:
1. "At what price is this too expensive?"
2. "At what price is this getting expensive, but you'd still consider it?"
3. "At what price is this a bargain?"
4. "At what price is this so cheap you'd question the quality?"

The overlap of answers 2 and 3 is your Acceptable Price Range.

## Freemium Design: The Right Constraints

The goal of a free tier is to let users experience your core value — not to give away everything.

### What to Gate

| Gate Type | Example | Conversion Impact |
|-----------|---------|------------------|
| Volume cap | 100 records → 1,000 | High — users hit wall naturally |
| Feature flag | Team/collaboration | Medium — solo users may not care |
| Data retention | 30 days → unlimited | Medium — matters after 30 days |
| Integrations | 1 webhook → unlimited | Low-Medium |

**Rule of thumb**: Free tier should cover the first meaningful use case, not the full product.

## Stripe + Supabase: Full Implementation

### Edge Function: Create Checkout Session

```typescript
// supabase/functions/billing-hub/index.ts
import Stripe from 'https://esm.sh/stripe@12'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

export async function createCheckout(userId: string, priceId: string): Promise<string> {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // Get or create Stripe customer
  const { data: profile } = await supabase
    .from('profiles')
    .select('stripe_customer_id, email')
    .eq('id', userId)
    .single()

  let customerId = profile?.stripe_customer_id
  if (!customerId) {
    const customer = await stripe.customers.create({ email: profile?.email })
    customerId = customer.id
    await supabase
      .from('profiles')
      .update({ stripe_customer_id: customerId })
      .eq('id', userId)
  }

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    subscription_data: { trial_period_days: 14 },
    success_url: `${Deno.env.get('APP_URL')}/billing/success?session={CHECKOUT_SESSION_ID}`,
    cancel_url: `${Deno.env.get('APP_URL')}/billing`,
  })

  return session.url!
}
```

### Webhook Handler for Subscription Sync

```typescript
export async function handleStripeWebhook(req: Request) {
  const body = await req.text()
  const sig = req.headers.get('stripe-signature')!
  const event = stripe.webhooks.constructEvent(
    body, sig, Deno.env.get('STRIPE_WEBHOOK_SECRET')!
  )

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  if (['customer.subscription.created', 'customer.subscription.updated']
       .includes(event.type)) {
    const sub = event.data.object as Stripe.Subscription
    await supabase.from('subscriptions').upsert({
      stripe_subscription_id: sub.id,
      stripe_customer_id: sub.customer as string,
      status: sub.status,
      plan_id: sub.items.data[0].price.id,
      current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
      cancel_at_period_end: sub.cancel_at_period_end,
    }, { onConflict: 'stripe_subscription_id' })
  }

  if (event.type === 'customer.subscription.deleted') {
    const sub = event.data.object as Stripe.Subscription
    await supabase
      .from('subscriptions')
      .update({ status: 'canceled' })
      .eq('stripe_subscription_id', sub.id)
  }

  return new Response('ok')
}
```

## Flutter: Plan-Gated UI

```dart
// Domain model
enum UserPlan { free, pro, team }

extension UserPlanX on UserPlan {
  bool get isPro => this == UserPlan.pro || this == UserPlan.team;
  bool get isTeam => this == UserPlan.team;
  int get exportLimit => switch (this) {
    UserPlan.free => 100,
    UserPlan.pro => 10000,
    UserPlan.team => 0, // unlimited
  };
}

// Gate widget
class PlanGate extends StatelessWidget {
  final Widget child;
  final String featureName;
  final bool Function(UserPlan) allowed;

  const PlanGate({
    required this.child,
    required this.featureName,
    required this.allowed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<UserPlanNotifier>().plan;
    if (allowed(plan)) return child;
    return _UpgradePrompt(featureName: featureName);
  }
}

// Usage
PlanGate(
  featureName: 'Team collaboration',
  allowed: (p) => p.isTeam,
  child: const TeamInviteButton(),
)
```

### Usage Limit Banner

```dart
class UsageLimitBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final usage = context.watch<UsageNotifier>();
    final plan = context.watch<UserPlanNotifier>().plan;
    final limit = plan.exportLimit;
    if (limit == 0) return const SizedBox.shrink();

    final pct = usage.exportsThisMonth / limit;
    if (pct < 0.8) return const SizedBox.shrink();

    return Container(
      color: pct >= 1.0 ? Colors.red.shade100 : Colors.orange.shade100,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(pct >= 1.0 ? Icons.lock : Icons.warning_amber),
        const SizedBox(width: 8),
        Expanded(child: Text(
          pct >= 1.0
            ? 'Monthly limit reached (${usage.exportsThisMonth}/$limit). Upgrade to continue.'
            : '${(pct * 100).round()}% of monthly limit used.',
        )),
        TextButton(onPressed: () => context.push('/billing'), child: const Text('Upgrade')),
      ]),
    );
  }
}
```

## Conversion Rate Optimization Checklist

- [ ] Upgrade CTA visible within 3 clicks from any screen
- [ ] Show upgrade prompt at the moment the user hits a limit
- [ ] Trial → paid automated email sequence: day 0, day 7 ("how's it going?"), day 12 ("trial ends soon")
- [ ] Annual pricing at 20% discount shown by default (increases LTV)
- [ ] Cancellation flow with personalized save offer (e.g., "Pause for 3 months?" or "50% off next 3 months?")
- [ ] Stripe Customer Portal for self-serve plan changes and billing

## Indie Dev Pricing Reference Points (2026)

- **Notion competitor**: $8-16/month (task management — high willingness to pay)
- **Developer tools**: $15-30/month (productivity ROI is calculable)
- **AI features**: Charge based on usage or flat $10-20/month add-on
- **Team plans**: 3-5x individual price per seat (justifiable by collaboration value)

## Summary

Indie SaaS monetization is a loop: define value → design freemium constraints → integrate Stripe → optimize conversion. Flutter + Supabase + Stripe delivers this with minimal backend complexity. The biggest leverage point: show the upgrade prompt at the exact moment users hit a limit, not buried in a settings menu.

Next: Dart Concurrency deep dive — Isolates 2.0, structured concurrency patterns, and async best practices.
