---
title: "Indie Dev SaaS Monetization: How to Improve Free-to-Paid Conversion"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev SaaS Monetization: How to Improve Free-to-Paid Conversion

"Lots of free users, no revenue" is a design problem. Here's how to fix it.

## The Core Problem

```
Typical indie SaaS:
  MAU: 500
  Free: 490 (98%)
  Paid:  10 ( 2%)
  MRR: $200 (avg $20/user)

Target:
  2% → 5% conversion = 2.5× MRR
  5% → 10% conversion = 5× MRR
```

## Tactic 1: Put a Ceiling on the Free Plan

```
Bad design (no conversion):
  Free = full features, with ads
  Paid = no ads + extra features
  → No reason to upgrade

Good design (natural conversion):
  Free = core features × capped quantity (3 projects / 100 items)
  Paid = unlimited + power-user features
  → Heavy users hit the wall naturally
```

**Example limits**:

```
Projects:          Free 3   / Pro unlimited
History:           Free 30d / Pro 12 months
AI generations:    Free 10/mo / Pro 500/mo
Export:            Free ✗  / Pro CSV + PDF
Team members:      Free 1  / Pro 5
```

## Tactic 2: Create Upgrade Moments

```dart
Widget buildProjectList() {
  final isAtLimit = _projects.length >= 3 && !_isPro;

  return Column(
    children: [
      ..._projects.map((p) => ProjectTile(project: p)),
      if (isAtLimit)
        UpgradePromptCard(
          message: 'Project limit reached (3/3)',
          ctaText: 'Upgrade to Pro for unlimited projects',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UpgradePage()),
          ),
        ),
    ],
  );
}
```

**Best moments to prompt an upgrade**:

```
✅ The instant the user hits a limit (highest conversion)
✅ Monthly report: "Pro shows 12 months — you're seeing 30 days"
✅ Export button grayed out + tooltip explaining why
✅ Email at 80% usage: "You're approaching your limit"
```

## Tactic 3: Annual Plans Increase LTV

```
Monthly:  $10/mo → $120/year
Annual:   $80/year (33% off)

User saves: $40/year
You gain: lower churn + upfront cash flow

Implementation: Stripe yearly price + coupon
```

## Tactic 4: Reverse Trial — Let Them Experience Paid First

```
Standard freemium:
  Free → hit wall → upgrade
  Problem: user never experiences Paid value before deciding

Reverse trial:
  Paid (14-day free) → downgrade to Free or continue
  Why it works: loss aversion — users don't want to lose features they've used
```

## Tactic 5: Pricing Page Design

```
❌ Bad:
  Standard $10/mo
  Pro      $20/mo

✅ Good:
  Standard $10/mo
  Pro      $20/mo  ← Most popular (badge)
  Business $50/mo

Three options → middle anchor effect
"Most popular" badge → social proof
```

## KPIs That Matter

```
Conversion rate = Paid ÷ (Free + Paid) × 100

Related metrics:
  Activation Rate:  % of users who use core feature within 7 days of signup
  Engagement Score: avg active days/week
  Feature Adoption: % who touch a Pro-only feature

→ High Activation Rate = much higher conversion rate
→ Track these 3 in Supabase, review weekly
```

## Summary

```
Limit design    → put a ceiling on Free (quantity, history, team)
Upgrade moments → prompt at the exact moment the wall is hit
Annual plans    → higher LTV + lower churn
Reverse trial   → let users experience Pro before deciding
Pricing page    → three tiers + "most popular" badge
```

Going from 2% to 5% conversion doubles your MRR. Converting existing users is faster than acquiring new ones.

