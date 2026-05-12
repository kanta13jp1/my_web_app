---
title: "Indie SaaS KPI Design and Measurement: MAU, ARR, NPS, and Churn"
tags: ai,indiedev,buildinpublic,automation
published: true
---

# Indie SaaS KPI Design and Measurement: MAU, ARR, NPS, and Churn

Without clarity on what to measure, your improvement loop never runs.

## KPI Selection Principles

```
North Star Metric (pick exactly one)
  ↓
Leading KPIs (3–5 metrics)
  ↓
Lagging KPIs (ARR/Churn → review monthly)
```

For indie SaaS, the North Star is usually **Weekly Active Users (WAU)** or
**number of times users succeed** (e.g., "tasks completed", "articles published").
ARR and MRR are outcomes, not goals.

## MAU / WAU / DAU — Your "Active" Definition Is Everything

```sql
-- MAU: Monthly Active Users
SELECT COUNT(DISTINCT user_id) AS mau
FROM user_events
WHERE created_at >= date_trunc('month', NOW())
  AND event_type IN ('page_view', 'task_create', 'task_complete');

-- WAU (last 7 days)
SELECT COUNT(DISTINCT user_id) AS wau
FROM user_events
WHERE created_at >= NOW() - INTERVAL '7 days';

-- Retention: active last month AND this month
SELECT COUNT(DISTINCT curr.user_id) AS retained
FROM (
  SELECT DISTINCT user_id FROM user_events
  WHERE created_at >= date_trunc('month', NOW())
) curr
JOIN (
  SELECT DISTINCT user_id FROM user_events
  WHERE created_at >= date_trunc('month', NOW() - INTERVAL '1 month')
    AND created_at < date_trunc('month', NOW())
) prev USING (user_id);
```

**Recording events from Flutter**:

```dart
await supabase.from('user_events').insert({
  'user_id': supabase.auth.currentUser?.id,
  'event_type': 'task_complete',
  'properties': {'task_type': 'daily_check'},
});
```

## ARR / MRR — Essential If You Charge

```
MRR = paid users × monthly ARPU
ARR = MRR × 12

Monthly churn = (paid end of last month - paid end of this month) / paid end of last month
NRR = (retained + upsell - churn) / last month's MRR
```

**Healthy benchmarks for indie/small SaaS**:

- Monthly churn < 5%
- NRR > 100% (upsells offsetting churn)
- Free-to-paid CVR > 3%

## NPS — "Would You Recommend?" Is a Leading Indicator

```
NPS = % Promoters (9–10) - % Detractors (0–6)
Target: > 0 (40+ is best in class)
```

Send one email 30 days after sign-up via Resend API:

```typescript
// Edge Function: send-nps-survey
const score = parseInt(payload.score);
await supabase.from('nps_responses').insert({
  user_id: payload.user_id,
  score,
  comment: payload.comment,
  responded_at: new Date().toISOString(),
});
```

## Dashboard Design

```
Weekly: WAU, new signups, task completion rate
Monthly: MAU, MRR, churn rate, NRR, NPS
```

Supabase + Metabase (self-hosted) works well. The Supabase Studio SQL editor is
often enough for indie scale. Write events continuously to `user_events` — you
can always aggregate anything later.

## Summary

```
North Star    → WAU or success-action count (industry-dependent)
Leading KPIs  → retention rate / feature usage / NPS
Lagging KPIs  → MRR / churn rate / ARR
Iron rule     → define "active" before writing any query
```

The act of measuring alone surfaces improvement ideas. Build the recording
infrastructure first — analysis follows naturally.
