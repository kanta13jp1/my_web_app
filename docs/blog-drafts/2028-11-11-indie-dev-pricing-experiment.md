---
title: "個人開発SaaSの価格設定実験 — A/Bテスト・アンカリング・Freemium戦略"
tags: AI,個人開発,buildinpublic,automation
published: true
---

# 個人開発SaaSの価格設定実験 — A/Bテスト・アンカリング・Freemium戦略

価格設定は機能開発と同じくらい重要な成長レバー。実際に試した手法をまとめる。

## 価格実験の基本構造

```sql
-- 価格プランテーブル
CREATE TABLE pricing_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,           -- 'starter', 'pro', 'team'
  price_monthly INTEGER NOT NULL, -- 円
  price_yearly INTEGER,
  features JSONB NOT NULL DEFAULT '[]',
  is_active BOOLEAN DEFAULT true,
  variant TEXT DEFAULT 'control' -- A/Bテスト用
);

-- ユーザーがどのバリアントを見たか
CREATE TABLE pricing_impressions (
  user_id UUID REFERENCES profiles(id),
  variant TEXT NOT NULL,
  converted BOOLEAN DEFAULT false,
  seen_at TIMESTAMPTZ DEFAULT NOW()
);
```

## アンカリング: 高価格プランを先に見せる

```dart
// 価格カードを高→低の順で表示
final plans = [
  PricingPlan(name: 'Team', price: 9800, highlight: false),
  PricingPlan(name: 'Pro', price: 2980, highlight: true),   // 推奨
  PricingPlan(name: 'Starter', price: 980, highlight: false),
];

// Team プランを先に見せることで Pro が「お得」に見える
Widget _buildPricingCards() {
  return Row(
    children: plans.map((p) => PricingCard(plan: p)).toList(),
  );
}
```

## Freemium から有料への転換トリガー

```typescript
// Edge Function: 利用量チェックとアップグレード促進
const LIMITS = { free: { projects: 3, members: 1 } };

export async function checkUsageLimit(userId: string, resource: string) {
  const { count } = await supabase
    .from(resource)
    .select('*', { count: 'exact', head: true })
    .eq('user_id', userId);

  const plan = await getUserPlan(userId);
  const limit = LIMITS[plan]?.[resource];

  if (limit && count >= limit) {
    return { blocked: true, upgradeUrl: '/pricing?ref=limit' };
  }
  return { blocked: false };
}
```

## 年払いディスカウントの心理効果

```dart
// 月払い vs 年払い比較表示
String get yearlyDiscount {
  final monthly = priceMonthly * 12;
  final yearly = priceYearly ?? monthly;
  final discount = ((monthly - yearly) / monthly * 100).round();
  return '$discount% OFF';
}

// 「年払いにすると×ヶ月分無料」という表現が効果的
String get freeMonthsText {
  final monthly = priceMonthly;
  final savings = (priceMonthly * 12) - (priceYearly ?? 0);
  final freeMonths = (savings / monthly).floor();
  return '$freeMonths ヶ月分お得';
}
```

## まとめ

```
アンカリング    → 高価格を先に見せて中間プランをお得に見せる
Freemium 転換  → 利用量上限でアップグレード誘導 (ref= パラメータでトラッキング)
年払い訴求     → 月額換算 + 無料ヶ月数で価値を可視化
A/B テスト    → pricing_impressions で転換率を測定・比較
```

価格設定は「一度決めたら終わり」ではなく、継続的に仮説→計測→改善を回すプロダクト機能。
