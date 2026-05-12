---
title: "個人開発SaaSのKPI設計と計測 — MAU/ARR/NPS/チャーンを正しく追う"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発SaaSのKPI設計と計測 — MAU/ARR/NPS/チャーンを正しく追う

「何を計測すべきか」が明確でないと、改善のループが回らない。

## KPI 選択の原則

```
North Star Metric (1つだけ)
  ↓
先行指標 (Leading KPIs: 3〜5個)
  ↓
遅行指標 (Lagging KPIs: ARR/Churn → 毎月確認)
```

個人開発 SaaS の North Star は通常 **週次アクティブユーザー数 (WAU)** か
**ユーザーが成功した回数** (例: 「タスク完了数」「記事公開数」)。
ARR や MRR は結果であって目標ではない。

## MAU / WAU / DAU — アクティブ定義が全て

```sql
-- MAU: 月間アクティブユーザー
SELECT COUNT(DISTINCT user_id) AS mau
FROM user_events
WHERE created_at >= date_trunc('month', NOW())
  AND event_type IN ('page_view', 'task_create', 'task_complete');

-- WAU (直近7日)
SELECT COUNT(DISTINCT user_id) AS wau
FROM user_events
WHERE created_at >= NOW() - INTERVAL '7 days';

-- 継続率: 先月アクティブ → 今月もアクティブ
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

**Flutter 側から計測イベントを送る**:

```dart
// Supabase Edge Function 経由でイベント記録
await supabase.from('user_events').insert({
  'user_id': supabase.auth.currentUser?.id,
  'event_type': 'task_complete',
  'properties': {'task_type': 'daily_check'},
});
```

## ARR / MRR — 課金があるなら必須

```
MRR (月次経常収益) = 有料ユーザー数 × 月額ARPU
ARR = MRR × 12

チャーン率 = 先月末有料数 - 今月末有料数 / 先月末有料数
Net Revenue Retention (NRR) = (継続 + アップセル - チャーン) / 先月末 MRR
```

**健全な目安 (個人/スモール SaaS)**:

- 月次チャーン率 < 5%
- NRR > 100% (アップセルで相殺できている)
- 無料→有料 CVR > 3%

## NPS — 「友人に勧めるか」は先行指標

```
NPS = % Promoters (9-10点) - % Detractors (0-6点)
目標: 0 以上 (40以上が best in class)
```

計測方法: ユーザー登録 30日後に 1 通のメール送信 (Resend API):

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

## 計測ダッシュボード設計

```
週1回確認: WAU, 新規登録数, タスク完了率
月1回確認: MAU, MRR, チャーン率, NRR, NPS
```

Supabase + Metabase でセルフホスト、または Supabase Studio の SQL エディタで十分。
無料プランでも `user_events` テーブルに書き込み続ければ後から何でも集計できる。

## まとめ

```
North Star    → WAU or 成功アクション数 (業種で決まる)
先行指標      → 継続率 / 機能別利用率 / NPS
遅行指標      → MRR / チャーン率 / ARR
計測の鉄則   → "アクティブ"の定義を先に決めてから実装する
```

計測するだけで改善のアイデアが自然と生まれる。まず「記録する仕組み」を作ることが最初の一手。
