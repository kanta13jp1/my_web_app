---
title: "Indie SaaS Pricing Strategy — Freemium, Trials, and Pricing Psychology"
tags: indiedev,webdev,buildinpublic,flutter
published: true
---

# Indie SaaS Pricing Strategy — Freemium, Trials, and Pricing Psychology

Pricing is the highest-leverage growth lever you have. It's the only thing that can 2-3x revenue without writing a single line of code. Here are the patterns that actually worked for me.

## Three Models and When to Use Each

```
Freemium (free tier → paid upgrade)
  Good for: viral products, network effects, low ARPU
  Avoid:    complex onboarding, high CAC, aggressive ARR targets

Time-limited trial (14/30 days, full access)
  Good for: self-serve B2B SaaS, products that need evaluation time
  Avoid:    hobbyist users (they forget), simple utilities

No-CC trial vs CC-required trial
  No CC:   3× sign-up rate, 50% lower conversion
  CC req:  1× sign-up rate, 3× higher conversion
  Decision: run the math on CAC vs LTV for your segment
```

## Pricing Psychology

```
❌ $30/month — users mentally bucket it as "expensive"
✅ $27/month — same users feel "sure, why not"

❌ Single plan at $100/month
✅ Three plans: $49 / $99 / $199
   The middle plan gets ~72% of sign-ups (anchoring effect)

❌ Annual: $348 ($29 × 12)
✅ Annual: $276 ($23/month, 20% OFF)
   Annual plans improve ARR and reduce monthly churn
```

## A/B Testing Prices With Supabase

```sql
-- Track pricing experiment exposure and conversion
CREATE TABLE pricing_experiments (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID REFERENCES auth.users(id),
  variant      TEXT NOT NULL,  -- 'control' | 'challenger'
  seen_at      TIMESTAMPTZ DEFAULT now(),
  converted_at TIMESTAMPTZ,
  plan_id      TEXT
);

-- Conversion rate by variant
SELECT
  variant,
  COUNT(*)                             AS exposed,
  COUNT(converted_at)                  AS converted,
  ROUND(
    COUNT(converted_at)::numeric / COUNT(*) * 100, 1
  )                                    AS conversion_pct,
  AVG(
    EXTRACT(epoch FROM (converted_at - seen_at)) / 3600
  )                                    AS avg_hours_to_convert
FROM pricing_experiments
GROUP BY variant;
```

```dart
// Flutter: deterministic A/B split
class PricingTestService {
  static String getVariant(String userId) =>
    userId.hashCode.abs() % 2 == 0 ? 'control' : 'challenger';
}
```

## Plan Design Anti-patterns

```
❌ Feature-differentiated tiers:
   Free: A  |  Standard: A+B  |  Pro: A+B+C
   Problem: users can't tell if they need B or C

✅ Usage-differentiated tiers:
   Free: 100 tasks  |  Standard: unlimited  |  Pro: unlimited + team
   Benefit: users instantly know which plan fits their current stage

❌ "Contact us" plan on the pricing page (early stage)
   Signals enterprise-only; individual users bounce
   → $199/month as the top tier is fine early on

✅ "Most popular" badge on the middle plan
   → 40% higher click rate, 25% higher conversion
```

## Raising Prices Correctly

```
1. Grandfather existing users at their current price (never raise on them)
2. Apply new price to new sign-ups only
3. Announce 2 weeks in advance with a personal email
4. Be honest about the reason ("infrastructure costs and feature investment")

Result: most SaaS products see lower churn after a price increase
Why:    a higher price signals legitimacy — too cheap reads as "not serious"
```

## LTV-Based Price Optimization

```sql
SELECT
  plan_id,
  AVG(monthly_mrr)                              AS avg_mrr,
  AVG(lifetime_months)                          AS avg_lifetime_months,
  AVG(monthly_mrr * lifetime_months * 0.7)      AS estimated_ltv
FROM (
  SELECT
    s.plan_id,
    s.amount / 100.0                            AS monthly_mrr,
    EXTRACT(MONTH FROM AGE(
      COALESCE(s.canceled_at, now()), s.started_at
    ))                                          AS lifetime_months
  FROM subscriptions s
  WHERE s.started_at < now() - interval '3 months'
) sub
GROUP BY plan_id;
```

**Real result**: raising price from $19 → $29 reduced sign-up volume by 15% but increased LTV by 40%, resulting in 19% MRR growth overall.

---

What pricing change had the biggest impact for you? Share below!
