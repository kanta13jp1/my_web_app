---
title: "Indie SaaS Monetization — Hard Paywall vs Freemium vs Usage-Based Pricing"
tags: supabase,flutter,webdev,indiedev
published: true
---

# Indie SaaS Monetization — Hard Paywall vs Freemium vs Usage-Based Pricing

The hardest decision in indie SaaS isn't building the product — it's deciding where to put the wall. Too low and nobody converts. Too high and nobody signs up. Here are three patterns with real implementation examples.

## Pattern 1: Hard Paywall (Action Limit)

Lock users out after N actions. Simple, predictable revenue.

```sql
CREATE TABLE usage_limits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id),
  action_count INTEGER DEFAULT 0,
  reset_at TIMESTAMPTZ DEFAULT date_trunc('month', NOW()) + INTERVAL '1 month',
  plan TEXT DEFAULT 'free'
);

CREATE OR REPLACE FUNCTION increment_usage(p_user_id UUID, p_limit INT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_count INTEGER;
  user_plan TEXT;
BEGIN
  SELECT action_count, plan INTO current_count, user_plan
  FROM usage_limits WHERE user_id = p_user_id;

  IF user_plan = 'pro' THEN RETURN TRUE; END IF;
  IF current_count >= p_limit THEN RETURN FALSE; END IF;

  UPDATE usage_limits SET action_count = action_count + 1
  WHERE user_id = p_user_id;

  RETURN TRUE;
END;
$$;
```

```dart
Future<bool> checkAndIncrementUsage() async {
  final allowed = await supabase.rpc('increment_usage', params: {
    'p_user_id': supabase.auth.currentUser!.id,
    'p_limit': 10,
  }) as bool;

  if (!allowed) _showUpgradeDialog();
  return allowed;
}
```

## Pattern 2: Freemium (Feature Gate)

Core free, advanced features paid. Best for user acquisition.

```dart
enum Plan { free, pro }

class FeatureGate extends StatelessWidget {
  final Plan requiredPlan;
  final Widget child;
  final Widget? fallback;

  const FeatureGate({
    required this.requiredPlan,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final plan = context.read<UserProvider>().plan;
    if (plan.index >= requiredPlan.index) return child;
    return fallback ?? UpgradePromptWidget(requiredPlan: requiredPlan);
  }
}

// Usage
FeatureGate(
  requiredPlan: Plan.pro,
  child: AIAnalysisButton(),
  fallback: ProTeaser(title: 'AI Analysis', description: 'Unlimited on Pro'),
)
```

## Pattern 3: Usage-Based (Credits)

Align price with value. Best for AI features where your cost scales with usage.

```sql
CREATE TABLE user_credits (
  user_id UUID PRIMARY KEY,
  credits INTEGER DEFAULT 100,
  total_used INTEGER DEFAULT 0
);

CREATE OR REPLACE FUNCTION consume_credits(p_user_id UUID, p_amount INTEGER)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE current_credits INTEGER;
BEGIN
  SELECT credits INTO current_credits
  FROM user_credits WHERE user_id = p_user_id;

  IF current_credits < p_amount THEN
    RETURN json_build_object('success', false, 'reason', 'insufficient_credits');
  END IF;

  UPDATE user_credits
  SET credits = credits - p_amount, total_used = total_used + p_amount
  WHERE user_id = p_user_id;

  RETURN json_build_object('success', true, 'remaining', current_credits - p_amount);
END;
$$;
```

## Payment Provider Comparison

| Provider | Indie-friendly | Tax handling | Notes |
|---|---|---|---|
| Stripe | ◎ | Manual | Most features; official Supabase integration |
| RevenueCat | ◎ | Platform handles | Best for in-app purchases |
| Lemon Squeezy | ○ | MoR (automatic) | Easiest for solo devs |
| Paddle | ○ | MoR (automatic) | Good EU VAT support |

## My Hybrid Approach

In my app (自分株式会社), I use freemium + usage-based:
- **Free**: core features + 100 AI credits/month
- **Pro ¥980/month**: unlimited AI + advanced analytics + data export

Conversion rate: ~3.2% (industry average 2-5%). The free tier is generous enough for users to see real value before deciding to pay.

---

What monetization model works for your indie app? I'd love to hear what conversion rates you're seeing.
