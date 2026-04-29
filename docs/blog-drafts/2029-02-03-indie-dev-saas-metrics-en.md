---
title: "Indie SaaS Metrics That Matter — Tracking MRR, Churn & LTV with Supabase"
tags: indiedev,ai,flutter,buildinpublic
published: true
---

# Indie SaaS Metrics That Matter — Tracking MRR, Churn & LTV with Supabase

Growing a SaaS business requires tracking the right metrics. This guide covers calculating MRR, Churn Rate, and LTV, then building a real-time dashboard with Supabase and Flutter.

## The 4 Essential SaaS Metrics

### 1. MRR (Monthly Recurring Revenue)

```
MRR = Paying Users × Average Monthly Price
```

- **New MRR**: Revenue from new users
- **Expansion MRR**: Upgrades/upsells
- **Churned MRR**: Revenue lost to cancellations
- **Net New MRR** = New MRR + Expansion MRR - Churned MRR

### 2. Churn Rate

```
Monthly Churn Rate = Cancellations this month / Users at month start × 100 (%)
```

Targets: B2C SaaS < 3%/month, B2B < 1%/month

### 3. LTV (Lifetime Value)

```
LTV = Avg Monthly Revenue × (1 / Monthly Churn Rate)
e.g. $9.99 × (1 / 0.03) ≈ $333
```

### 4. CAC (Customer Acquisition Cost)

```
CAC = Total Marketing Spend / New Users Acquired
Healthy ratio: LTV / CAC ≥ 3
```

## Calculating Metrics in Supabase

```sql
-- MRR view
CREATE OR REPLACE VIEW mrr_monthly AS
SELECT
  DATE_TRUNC('month', s.created_at) AS month,
  COUNT(DISTINCT s.user_id) AS active_subscriptions,
  SUM(p.amount_usd) AS mrr_usd,
  COUNT(DISTINCT CASE WHEN s.status = 'canceled' THEN s.user_id END) AS churned
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.status IN ('active', 'canceled')
GROUP BY DATE_TRUNC('month', s.created_at)
ORDER BY month DESC;

-- LTV function
CREATE OR REPLACE FUNCTION calculate_ltv()
RETURNS NUMERIC AS $$
DECLARE
  avg_revenue NUMERIC;
  churn_rate NUMERIC;
BEGIN
  SELECT AVG(p.amount_usd) INTO avg_revenue
  FROM subscriptions s JOIN plans p ON s.plan_id = p.id
  WHERE s.status = 'active';

  SELECT
    COUNT(CASE WHEN status = 'canceled' THEN 1 END)::NUMERIC /
    NULLIF(COUNT(*), 0)
  INTO churn_rate
  FROM subscriptions
  WHERE created_at >= NOW() - INTERVAL '30 days';

  RETURN CASE WHEN churn_rate > 0 THEN avg_revenue / churn_rate ELSE 0 END;
END;
$$ LANGUAGE plpgsql;
```

## Edge Function Metrics API

```typescript
export async function getMetrics(supabase: SupabaseClient) {
  const [mrrResult, ltvResult] = await Promise.all([
    supabase.from('mrr_monthly').select('*').limit(12),
    supabase.rpc('calculate_ltv'),
  ]);

  const latest = mrrResult.data?.[0];
  return {
    mrr: latest?.mrr_usd ?? 0,
    activeSubscriptions: latest?.active_subscriptions ?? 0,
    churned: latest?.churned ?? 0,
    ltv: ltvResult.data ?? 0,
    churnRate: latest ? (latest.churned / latest.active_subscriptions) * 100 : 0,
  };
}
```

## Flutter Dashboard Widget

```dart
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final Color? trendColor;

  const MetricCard({super.key, required this.label, required this.value,
      this.trend, this.trendColor});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          if (trend != null) Text(trend!, style: TextStyle(color: trendColor)),
        ],
      ),
    ),
  );
}

GridView.count(
  crossAxisCount: 2,
  children: [
    MetricCard(label: 'MRR', value: '\$${metrics.mrr.toStringAsFixed(0)}',
        trend: '+\$120 vs last month', trendColor: Colors.green),
    MetricCard(label: 'Churn Rate', value: '${metrics.churnRate.toStringAsFixed(1)}%',
        trend: metrics.churnRate < 3 ? '✅ On target' : '⚠️ Needs attention',
        trendColor: metrics.churnRate < 3 ? Colors.green : Colors.orange),
    MetricCard(label: 'LTV', value: '\$${metrics.ltv.toStringAsFixed(0)}'),
    MetricCard(label: 'Active Users', value: '${metrics.activeSubscriptions}'),
  ],
)
```

## MRR Chart with fl_chart

```dart
import 'package:fl_chart/fl_chart.dart';

LineChart(LineChartData(
  lineBarsData: [
    LineChartBarData(
      spots: mrrHistory.asMap().entries.map((e) =>
        FlSpot(e.key.toDouble(), e.value.mrrUsd.toDouble())
      ).toList(),
      isCurved: true,
      color: Theme.of(context).colorScheme.primary,
      barWidth: 3,
      dotData: const FlDotData(show: false),
    ),
  ],
))
```

## Summary

Monitoring MRR, Churn, and LTV weekly gives you a clear picture of SaaS health. Aggregate calculations in Supabase views and Edge Functions, then visualize with Flutter for a real-time metrics dashboard.

---

Building an AI Life Management app with Flutter × Supabase at 自分株式会社. Sharing indie dev insights every week.
