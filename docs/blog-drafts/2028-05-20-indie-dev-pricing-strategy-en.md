---
title: "Indie Dev Pricing Strategy 2.0 — Freemium Design and Upsell Mechanics"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev Pricing Strategy 2.0 — Freemium Design and Upsell Mechanics

"What should I charge?" is the wrong question. "Where do I put the wall?" is the right one.

## Freemium Design Principles

```
Free plan  = enough value to make users feel the product
Paid plan  = features that users naturally want when they want more
```

**Types of walls**:

```
Quantity limit  → Free: 3 projects / Paid: unlimited
Feature limit   → Free: core features / Paid: AI analysis & export
Storage limit   → Free: 1GB / Paid: 10GB
Team limit      → Free: solo / Paid: team collaboration
```

**Design rules**:

- Place the wall where users need it *right now* (gating future features doesn't work)
- Let users feel "wow, this is useful" on the free plan — then hit the wall
- Build a structure where 90%+ of users who cross the wall never go back to free

## Upsell Timing

```dart
// Track usage in Supabase and prompt at the right moment
Future<void> checkUpgradePrompt(String userId) async {
  final { data } = await supabase
      .from('usage_stats')
      .select('project_count, task_count')
      .eq('user_id', userId)
      .single();

  final projectCount = data['project_count'] as int;

  // Suggest upgrade at 80% of the free limit
  if (projectCount >= 2) {  // 80% of free limit of 3
    _showUpgradeHint('1 project left before you hit the limit. Go unlimited with Pro.');
  }
}
```

## Setting Your Price

```
Target: $70k/year revenue
  $7/mo  × 833 users = $5,831/mo = $69,972/yr
  $14/mo × 417 users = same
  $35/mo × 167 users = same

417–833 paid users is a realistic goal for an indie product.
```

**A/B Testing Prices**:

```dart
// Price A/B test via Supabase
final userGroup = userId.hashCode % 2;  // 0 or 1
final price = userGroup == 0 ? 7 : 10;  // USD

// Measure which group converts better
await supabase.from('price_experiments').insert({
  'user_id': userId,
  'group': userGroup,
  'price': price,
  'shown_at': DateTime.now().toIso8601String(),
});
```

## Churn Prevention

```
Top reasons for cancellation:
  1. Stopped using it (engagement dropped)
  2. Felt too expensive (perceived value decreased)
  3. Switched to a competitor

Countermeasures:
  1. Auto-email after 30 days of no login (Resend API)
  2. Offer "pause" before cancellation (50% off for 3 months)
  3. Always ask for cancellation reason (just 1 question)
```

```typescript
// Edge Function: churning-user-email
// Email users inactive for 30+ days
const inactiveUsers = await supabase
  .from('profiles')
  .select('email, name')
  .lt('last_active_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString())
  .eq('plan', 'pro');

for (const user of inactiveUsers) {
  await resend.emails.send({
    from: 'noreply@myapp.com',
    to: user.email,
    subject: `Hey ${user.name}, how have you been?`,
    html: winbackEmailTemplate(user),
  });
}
```

## Summary

```
Wall design       → 4 types: quantity / feature / storage / team + prompt at 80%
Pricing           → back-calculate from revenue target + always A/B test
Churn prevention  → 30-day inactivity email + pause option + exit survey
```

Price is the highest-leverage growth dial. A 1% price optimization beats a 1% user growth, every time.
