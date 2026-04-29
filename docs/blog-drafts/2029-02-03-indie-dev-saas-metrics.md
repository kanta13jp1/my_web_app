---
title: "インディー SaaS の必須メトリクス — MRR・Churn・LTV を Supabase で可視化する"
tags: 個人開発,AI,flutter,indiedev
published: true
---

# インディー SaaS の必須メトリクス — MRR・Churn・LTV を Supabase で可視化する

SaaS ビジネスを成長させるには正しいメトリクスの把握が欠かせません。MRR・Churn Rate・LTV など主要指標の計算方法と、Supabase + Flutter でダッシュボードを作る方法を解説します。

## SaaS の 4 大必須メトリクス

### 1. MRR (Monthly Recurring Revenue / 月次経常収益)

```
MRR = 有料ユーザー数 × 平均月額料金
```

- **New MRR**: 新規ユーザーから得た収益
- **Expansion MRR**: アップグレードによる追加収益
- **Churned MRR**: 解約による損失収益
- **Net New MRR** = New MRR + Expansion MRR - Churned MRR

### 2. Churn Rate (解約率)

```
月次 Churn Rate = 当月解約数 / 月初ユーザー数 × 100 (%)
```

目標: B2C SaaS は月次 2-3% 以下、B2B は 0.5-1% 以下

### 3. LTV (Lifetime Value / 顧客生涯価値)

```
LTV = 平均月額 × (1 / 月次 Churn Rate)
例: ¥980 × (1 / 0.03) ≈ ¥32,667
```

### 4. CAC (Customer Acquisition Cost / 顧客獲得コスト)

```
CAC = 総マーケティング費用 / 新規獲得ユーザー数
健全: LTV / CAC ≥ 3
```

## Supabase でメトリクスを計算する

```sql
-- MRR 計算ビュー
CREATE OR REPLACE VIEW mrr_monthly AS
SELECT
  DATE_TRUNC('month', s.created_at) AS month,
  COUNT(DISTINCT s.user_id) AS active_subscriptions,
  SUM(p.amount_jpy) AS mrr_jpy,
  COUNT(DISTINCT CASE WHEN s.status = 'canceled' THEN s.user_id END) AS churned
FROM subscriptions s
JOIN plans p ON s.plan_id = p.id
WHERE s.status IN ('active', 'canceled')
GROUP BY DATE_TRUNC('month', s.created_at)
ORDER BY month DESC;

-- LTV 計算
CREATE OR REPLACE FUNCTION calculate_ltv()
RETURNS NUMERIC AS $$
DECLARE
  avg_revenue NUMERIC;
  churn_rate NUMERIC;
BEGIN
  SELECT AVG(p.amount_jpy) INTO avg_revenue
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

## Edge Function でメトリクス API

```typescript
// supabase/functions/schedule-hub/metrics.ts
export async function getMetrics(supabase: SupabaseClient) {
  const [mrrResult, churnResult] = await Promise.all([
    supabase.from('mrr_monthly').select('*').limit(12),
    supabase.rpc('calculate_ltv'),
  ]);

  const latestMrr = mrrResult.data?.[0];
  return {
    mrr: latestMrr?.mrr_jpy ?? 0,
    activeSubscriptions: latestMrr?.active_subscriptions ?? 0,
    churned: latestMrr?.churned ?? 0,
    ltv: churnResult.data ?? 0,
    churnRate: latestMrr
      ? (latestMrr.churned / latestMrr.active_subscriptions) * 100
      : 0,
  };
}
```

## Flutter ダッシュボード Widget

```dart
class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;
  final Color? trendColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
    this.trendColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
            if (trend != null)
              Text(
                trend!,
                style: TextStyle(color: trendColor ?? Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// ダッシュボード画面
GridView.count(
  crossAxisCount: 2,
  children: [
    MetricCard(
      label: 'MRR',
      value: '¥${NumberFormat('#,###').format(metrics.mrr)}',
      trend: '+¥12,000 先月比',
      trendColor: Colors.green,
    ),
    MetricCard(
      label: 'Churn Rate',
      value: '${metrics.churnRate.toStringAsFixed(1)}%',
      trend: metrics.churnRate < 3 ? '✅ 目標内' : '⚠️ 要改善',
      trendColor: metrics.churnRate < 3 ? Colors.green : Colors.orange,
    ),
    MetricCard(
      label: 'LTV',
      value: '¥${NumberFormat('#,###').format(metrics.ltv)}',
    ),
    MetricCard(
      label: 'アクティブ',
      value: '${metrics.activeSubscriptions} 人',
    ),
  ],
)
```

## MRR チャート (fl_chart)

```dart
import 'package:fl_chart/fl_chart.dart';

LineChart(
  LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: mrrHistory.asMap().entries.map((e) =>
          FlSpot(e.key.toDouble(), e.value.mrrJpy.toDouble())
        ).toList(),
        isCurved: true,
        color: Theme.of(context).colorScheme.primary,
        barWidth: 3,
        dotData: const FlDotData(show: false),
      ),
    ],
  ),
)
```

## アラート設定

```sql
-- Churn Rate が 5% 超えたら通知
CREATE OR REPLACE FUNCTION check_churn_alert()
RETURNS TRIGGER AS $$
BEGIN
  IF (NEW.churned::NUMERIC / NULLIF(NEW.active_subscriptions, 0)) > 0.05 THEN
    PERFORM pg_notify('churn_alert',
      json_build_object('month', NEW.month, 'churn_rate',
        ROUND((NEW.churned::NUMERIC / NEW.active_subscriptions) * 100, 2)
      )::text
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## まとめ

MRR・Churn・LTV の 3 指標を週次でモニタリングするだけで、SaaS の健全度が見えてきます。Supabase のビューと Edge Function で計算を集約し、Flutter で可視化することで、リアルタイムのメトリクスダッシュボードが完成します。

---

自分株式会社では Flutter × Supabase でAIライフマネジメントアプリを開発中。個人開発の知見を毎週発信しています。
