---
title: "個人開発SaaSの成長指標 — MRR・チャーン・LTV を毎週追う"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発SaaSの成長指標 — MRR・チャーン・LTV を毎週追う

指標を追わないと何が効いているかわからない。個人開発で必須の 5 指標を整理する。

## 必須 5 指標

```
MRR (Monthly Recurring Revenue): 月次経常収益
  = 有料ユーザー数 × 月額料金
  目標: 前月比 +10% (月次複利で年2.5倍)

Churn Rate (解約率):
  = 解約ユーザー数 / 期初ユーザー数
  目標: < 5% / 月 (年間70%以上の残留率)

LTV (顧客生涯価値):
  = 月額料金 / 月次チャーン率
  例: ¥980/月、チャーン3% → LTV = ¥32,667

CAC (顧客獲得コスト):
  = 総マーケ費用 / 新規有料ユーザー数
  目標: LTV/CAC > 3

NRR (Net Revenue Retention):
  = (期初MRR + 拡張 - 縮小 - 解約) / 期初MRR
  目標: > 100% (拡張収益がチャーンを上回る)
```

## Supabase で指標を自動計算

```sql
-- 週次指標を集計するビュー
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

## GHA で毎週 Slack 通知

```typescript
// supabase/functions/weekly-growth-report/index.ts
const { data } = await supabase.rpc('get_growth_metrics');

const message = `
📊 週次グロースレポート ${new Date().toLocaleDateString('ja-JP')}
MRR: ¥${data.mrr.toLocaleString()} (前週比 ${data.mrr_growth > 0 ? '+' : ''}${data.mrr_growth}%)
有料ユーザー: ${data.active_users}人
チャーン: ${data.churned_users}人 (${data.churn_rate}%)
LTV: ¥${data.ltv.toLocaleString()}
`;

await fetch(Deno.env.get('SLACK_WEBHOOK')!, {
  method: 'POST',
  body: JSON.stringify({ text: message }),
});
```

## チャーン分析: 離脱ユーザーへの自動メール

```typescript
// 解約後 3 日経過のユーザーに再エンゲージメントメール
case 'customer.subscription.deleted': {
  const sub = event.data.object;
  const userId = sub.metadata.user_id;

  // 3日後にメール送信をスケジュール
  await supabase.from('email_queue').insert({
    user_id: userId,
    template: 'churn_winback',
    send_at: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString(),
  });
}
```

## まとめ

```
追うべき5指標  → MRR / Churn / LTV / CAC / NRR
優先順位      → まず Churn を下げる (MRR成長より先)
自動化        → Supabase view + GHA weekly schedule + Slack通知
アラート      → Churn > 5% or MRR前週比 -5% でSlack即時通知
```

指標は週1回ではなく「常に見える化」するのが個人開発では現実的な上限。
