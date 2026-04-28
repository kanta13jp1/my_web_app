---
title: "Indie Dev SaaS Growth Metrics — Track MRR, Churn, and LTV Every Week"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie Dev SaaS Growth Metrics — Track MRR, Churn, and LTV Every Week

Without tracking metrics you can't tell what's working. These are the 5 essential metrics for indie SaaS.

## The 5 Essential Metrics

```
MRR (Monthly Recurring Revenue):
  = paying users × monthly plan price
  Target: +10% MoM (compounding to 2.5× per year)

Churn Rate:
  = churned users / users at start of period
  Target: < 5% / month (70%+ annual retention)

LTV (Lifetime Value):
  = monthly price / monthly churn rate
  Example: $9.90/mo, 3% churn → LTV = $330

CAC (Customer Acquisition Cost):
  = total marketing spend / new paid users
  Target: LTV / CAC > 3

NRR (Net Revenue Retention):
  = (starting MRR + expansion - contraction - churn) / starting MRR
  Target: > 100% (expansion outpaces churn)
```

## Auto-Calculate Metrics in Supabase

```sql
-- View to aggregate weekly metrics
CREATE OR REPLACE VIEW weekly_metrics AS
SELECT
  date_trunc('week', s.created_at) AS week,
  COUNT(*) FILTER (WHERE s.status = 'active') AS active_subscriptions,
  SUM(p.amount) FILTER (WHERE s.status = 'active') / 100.0 AS mrr,
  COUNT(*) FILTER (WHERE s.status = 'canceled'
                   AND s.updated_at >= date_trunc('week', NOW()) - INTERVAL '1 week') AS churned_this_week,
  AVG(EXTRACT(EPOCH FROM (s.updated_at - s.created_at)) / 86400.0)
    FILTER (WHERE s.status = 'canceled') AS avg_days_to_churn
FROM subscriptions s
JOIN prices p ON s.price_id = p.id
GROUP BY 1;
```

## Weekly Slack Notification via GHA

```typescript
// supabase/functions/weekly-growth-report/index.ts
const { data } = await supabase.rpc('get_growth_metrics');

const message = `
📊 Weekly Growth Report ${new Date().toLocaleDateString('en-US')}
MRR: $${data.mrr.toLocaleString()} (${data.mrr_growth > 0 ? '+' : ''}${data.mrr_growth}% WoW)
Paying users: ${data.active_users}
Churned: ${data.churned_users} (${data.churn_rate}%)
LTV: $${data.ltv.toLocaleString()}
`;

await fetch(Deno.env.get('SLACK_WEBHOOK')!, {
  method: 'POST',
  body: JSON.stringify({ text: message }),
});
```

## Churn Analysis: Automated Win-Back Email

```typescript
// Send re-engagement email 3 days after cancellation
case 'customer.subscription.deleted': {
  const sub = event.data.object;
  const userId = sub.metadata.user_id;

  // Schedule email for 3 days later
  await supabase.from('email_queue').insert({
    user_id: userId,
    template: 'churn_winback',
    send_at: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
  });
}
```

## Summary

```
5 metrics to track → MRR / Churn / LTV / CAC / NRR
Priority           → reduce Churn first (before optimizing MRR growth)
Automation         → Supabase view + GHA weekly schedule + Slack notification
Alerts             → Churn > 5% or MRR -5% WoW → immediate Slack ping
```

For indie devs, "always visible" metrics beat weekly manual reviews every time.
