---
title: "Indie Dev SaaS Pricing Experiments — A/B Testing, Anchoring, and Freemium Strategy"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev SaaS Pricing Experiments — A/B Testing, Anchoring, and Freemium Strategy

Pricing is as powerful a growth lever as building features. Here's what actually worked.

## Core Pricing Experiment Schema

```sql
-- Pricing plans table
CREATE TABLE pricing_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,           -- 'starter', 'pro', 'team'
  price_monthly INTEGER NOT NULL, -- cents / yen
  price_yearly INTEGER,
  features JSONB NOT NULL DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  variant TEXT DEFAULT 'control' -- for A/B testing
);

-- Track which variant each user saw
CREATE TABLE pricing_impressions (
  user_id UUID REFERENCES profiles(id),
  variant TEXT NOT NULL,
  converted BOOLEAN DEFAULT false,
  seen_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Anchoring: Show the Expensive Plan First

```dart
// Display pricing cards high → low order
final plans = [
  PricingPlan(name: 'Team', price: 9800, highlight: false),
  PricingPlan(name: 'Pro', price: 2980, highlight: true),   // recommended
  PricingPlan(name: 'Starter', price: 980, highlight: false),
];

// Showing Team plan first makes Pro look like a deal
Widget _buildPricingCards() {
  return Row(
    children: plans.map((p) => PricingCard(plan: p)).toList(),
  );
}
```

## Freemium → Paid Conversion Trigger

```typescript
// Edge Function: usage check + upgrade nudge
const LIMITS = { free: { projects: 3, members: 1 } };

export async function checkUsageLimit(userId: string, resource: string) {
  const { count } = await supabase
    .from(resource)
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId);

  const plan = await getUserPlan(userId);
  const limit = LIMITS[plan]?.[resource];

  if (limit && count >= limit) {
    return { blocked: true, upgradeUrl: '/pricing?ref=limit' };
  }
  return { blocked: false };
}
```

## Annual Discount Psychology

```dart
// Monthly vs annual comparison display
String get yearlyDiscount {
  final monthly = priceMonthly * 12;
  final yearly = priceYearly ?? monthly;
  final discount = ((monthly - yearly) / monthly * 100).round();
  return '$discount% OFF';
}

// "X months free" framing outperforms "Y% off"
String get freeMonthsText {
  final monthly = priceMonthly;
  final savings = (priceMonthly * 12) - (priceYearly ?? 0);
  final freeMonths = (savings / monthly).floor();
  return '$freeMonths months free';
}
```

## Summary

```
Anchoring         → Show high-tier first; middle tier looks affordable
Freemium trigger  → Block at usage limit + ref= param for conversion tracking
Annual discount   → "X months free" framing > percentage discount
A/B testing       → pricing_impressions table tracks variant → conversion rate
```

Pricing isn't a one-time decision — treat it as a product feature with continuous hypothesis → measure → iterate cycles.
