---
title: "個人開発 SaaS ローンチ戦略 — 価格設定・Stripe 課金・フリーミアム設計"
tags: Flutter,個人開発,webdev,programming
published: true
---

個人開発でSaaSをローンチする際の最大の悩みは「どう収益化するか」です。価格設定・課金フロー・フリーミアム設計の実践ノウハウを、Flutter + Supabase + Stripe で構築する方法とともに解説します。

## 価格設定の原則

### バリュー・ベース・プライシング

機能数ではなく「顧客が得る価値」で価格を決める。

| NG例 | OK例 |
|------|------|
| ストレージ 5GB → $5 | 時間を月10時間節約 → $29 |
| 機能 X にアクセス → $10 | プロジェクト管理の自動化 → $49 |

### Willingness to Pay 調査

ローンチ前にターゲット 20〜30 人にインタビュー:

1. 「このツールに月いくら払いますか?」
2. 「高すぎると感じる金額は?」
3. 「安すぎて品質を疑う金額は?」

Van Westendorp モデルで「Acceptable Price Range」を導出。

## フリーミアム設計の鉄則

### 制限をかけるべき軸

| 制限軸 | 例 | 変換率への影響 |
|--------|-----|-------------|
| 量的上限 | 月100件 → 500件 | 高い (壁を感じやすい) |
| 機能フラグ | チームワーク機能 | 中 (一人使いには不要) |
| データ保持期間 | 30日 → 無制限 | 中 (長期ユーザーに効く) |
| カスタマイズ | テーマ数・API連携 | 低〜中 |

フリー枠は「価値を体験できる十分な量」が原則。制限が厳しすぎると離脱率上昇。

## Stripe + Supabase 実装

### Edge Function: チェックアウトセッション作成

```typescript
// supabase/functions/billing-hub/index.ts
import Stripe from 'https://esm.sh/stripe@12'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

async function createCheckoutSession(userId: string, priceId: string) {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const { data: profile } = await supabase
    .from('profiles')
    .select('stripe_customer_id, email')
    .eq('id', userId)
    .single()

  let customerId = profile?.stripe_customer_id
  if (!customerId) {
    const customer = await stripe.customers.create({ email: profile?.email })
    customerId = customer.id
    await supabase
      .from('profiles')
      .update({ stripe_customer_id: customerId })
      .eq('id', userId)
  }

  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    mode: 'subscription',
    success_url: `${Deno.env.get('APP_URL')}/billing/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${Deno.env.get('APP_URL')}/billing/cancel`,
  })

  return session.url
}
```

### Webhook でサブスクリプション状態同期

```typescript
async function handleWebhook(req: Request) {
  const sig = req.headers.get('stripe-signature')!
  const body = await req.text()
  const event = stripe.webhooks.constructEvent(
    body, sig, Deno.env.get('STRIPE_WEBHOOK_SECRET')!
  )

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  switch (event.type) {
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const sub = event.data.object as Stripe.Subscription
      await supabase.from('subscriptions').upsert({
        stripe_subscription_id: sub.id,
        stripe_customer_id: sub.customer as string,
        status: sub.status,
        current_period_end: new Date(sub.current_period_end * 1000).toISOString(),
        plan: sub.items.data[0].price.id,
      })
      break
    }
    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription
      await supabase
        .from('subscriptions')
        .update({ status: 'canceled' })
        .eq('stripe_subscription_id', sub.id)
      break
    }
  }

  return new Response('ok')
}
```

## Flutter 側: プランゲート

```dart
class PlanGate extends StatelessWidget {
  final Widget child;
  final Widget lockedWidget;
  final bool Function(UserPlan) allowedFor;

  const PlanGate({
    required this.child,
    required this.lockedWidget,
    required this.allowedFor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<UserPlanProvider>().plan;
    return allowedFor(plan) ? child : lockedWidget;
  }
}

// 使用例
PlanGate(
  allowedFor: (plan) => plan.isPro,
  lockedWidget: const UpgradePromptCard(feature: 'チームワーク'),
  child: const TeamWorkspacePage(),
)
```

## 変換率改善のチェックポイント

- [ ] フリー → 有料のアップグレードボタンは目立つ場所に配置
- [ ] 制限に達した瞬間にアップセル UI を表示
- [ ] トライアル 14日 → 有料移行の自動メール (3通) を設定
- [ ] 年払いディスカウント 20% を提示 (LTV 向上)
- [ ] キャンセル時のパーソナライズオファー (3ヶ月 50% OFF)

## まとめ

個人開発 SaaS の収益化は「価値定義 → フリーミアム設計 → Stripe 統合 → 変換率最適化」のループです。Flutter + Supabase + Stripe は最小コードで実装できる最強スタックの一つです。

次回: Dart 並行処理 (Isolates 2.0・structured concurrency・async patterns) を解説します。
