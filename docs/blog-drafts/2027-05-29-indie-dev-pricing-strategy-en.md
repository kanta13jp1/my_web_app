---
title: "Indie Dev Pricing Strategy: Freemium, Subscriptions, and Usage-Based Models"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev Pricing Strategy: Freemium, Subscriptions, and Usage-Based Models

Pricing is one of the hardest decisions in indie development. Price wrong and no one buys even if you give it away. Here are the three patterns I've tried.

## The Short Version

```
Freemium:        fastest user acquisition / hardest monetization
Flat subscription: simple / predictable / churn is also fast
Usage-based:     pay for what you use / powerful for heavy users
```

Which is right depends on your product. But **start free — always**.

## Why Start Free

```
Free period goals:
  1. Verify PMF (Product-Market Fit)
  2. Prove you're creating enough value to charge for
  3. Observe usage patterns
  4. Find users who say "I can't live without this"
```

If it's not used free, it won't be bought paid. Prove value first.

## Pattern 1: Freemium

```
Free tier:
  - All core features
  - 100 items/month (usage limit)
  - 1 user only

Pro: $9/month
  - Unlimited
  - Team sharing
  - Priority support
```

**Pros**:
- Fastest user acquisition
- Free users spread the word through blogs and social
- Users experience value before paying

**Cons**:
- Free user support cost is heavy
- Conversion rate is low (2-5%)
- You must clearly communicate "why pay"

**Conversion triggers**:

```
- When they hit the limit (100 → 101st item prompts upgrade)
- When they discover a pro feature (team sharing)
- After sustained heavy use (7 consecutive login days)
```

## Pattern 2: Flat Subscription

```
Monthly: $12/month or $99/year (17% off annual)
Trial: 14 days free (no credit card required)
```

**Pros**:
- Predictable revenue (MRR)
- Simple to explain
- Annual discount encourages long-term commitment

**Cons**:
- Churn spikes when trials end
- You must prove value worth paying every month

**Reducing churn**:

```dart
void showCancellationDialog() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Cancel subscription?'),
      content: Column(children: [
        const Text('You\'ll lose access to:'),
        // Show features they've actually used
        ...usedFeatures.map((f) => Text('• $f')),
        const Text('You can also downgrade instead'),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep plan')),
        TextButton(onPressed: _processCancellation, child: const Text('Cancel')),
      ],
    ),
  );
}
```

## Pattern 3: Usage-Based

```
Base: free ($0/month)
Usage charges:
  - AI responses: $0.01/each
  - Storage: $0.50/GB/month
  - API calls: $0.001/request
```

**Pros**:
- Fair — pay for what you use
- Heavy users naturally generate more revenue
- Low-cost users can stay on indefinitely

**Cons**:
- Unpredictable bills (users get anxious)
- Complex billing implementation (Stripe Metered Billing)
- "Bill shock" causes churn spikes

**Implementation with Supabase + Stripe**:

```typescript
async function recordUsage(userId: string, quantity: number) {
  const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!);
  await stripe.subscriptionItems.createUsageRecord(subscriptionItemId, {
    quantity,
    timestamp: Math.floor(Date.now() / 1000),
    action: 'increment',
  });
}
```

## How to Set the Price

```
Cost-based (wrong): cost × 3 → often underprices or misses value

Value-based (right):
  1. Research what users pay for alternatives (competitor pricing)
  2. Ask users directly: "What would you pay without hesitation?"
  3. 50-80% of competitors → no differentiation needed
     100-150% of competitors → need clear value-add justification
```

## A/B Test Prices — It's Allowed

```dart
// Price A/B test via Supabase feature flags
final testGroup = await supabase.rpc('get_price_ab_group', params: {'user_id': userId});
final price = testGroup == 'A' ? 9.99 : 14.99;
```

With 1,000 active users, you can measure the effect of a price change in 2 weeks.

## Summary

Pricing strategy checklist:
1. Start free → verify PMF
2. Find 5 users who say "I can't live without this"
3. Ask those 5 what they'd pay
4. Choose freemium / subscription / usage-based based on your product
5. Implement → measure → experiment when unsure

Price is a hypothesis, not a decision. Change it. Learn from the change.
