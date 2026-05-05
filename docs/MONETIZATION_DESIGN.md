# Monetization Design — Stripe + Freemium (#1305 / part 142)

> **status**: 設計 spec / Win版#132 part 142 / 2026-05-05
> **issue**: [#1305](https://github.com/kanta13jp1/my_web_app/issues/1305) [追加要望] 初期リリース用 Stripe 決済基盤の統合とフリーミアムモデル導入
> **scope**: 設計のみ (Win Claude territory) / 実装は Win Codex (= EF Deno + Flutter widget) ハンドオフ
> **NotebookLM source**: `bc98957a` The 30-Day SaaS Blueprint: From Zero to $1,287 MRR

## 1. Tier matrix

| tier | 月額 | 無料枠 | 主要機能 | target ARPU |
|---|---:|---|---|---:|
| **Free** | ¥0 | AI 質問 30 回/月 / EF call 100 回/月 / 自分株式会社 6 部署 read-only | onboarding / 価値検証 | ¥0 |
| **Pro** | **¥980** (= USD 9.99 ≒ JPY 980 + tax 内含) | 無制限 + AI 大学全コース + Mobile UAT priority | indie 個人 fits | ¥980 |
| **Team** (= future) | ¥2,980/seat | Pro 全機能 + 5 user share + audit log | small team / part 143+ | ¥2,980 |

Tier 戦略根拠 (= NotebookLM bc98957a):
- 「課金の先延ばしはプロダクトの真の価値検証を妨げる」(= 即課金で signal 取得)
- ¥980 は「Indie monthly」最頻価格帯 (= ChatGPT Plus / Notion Plus と同価格 anchor)

## 2. Stripe schema (= Supabase 側 / 既存 `users` 拡張)

### 新 schema (= 1 migration / Win Codex 担当)

```sql
-- supabase/migrations/<YYYYMMDDHHMMSS>_create_billing_tables.sql

CREATE TABLE public.billing_subscriptions (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  stripe_customer_id text UNIQUE NOT NULL,
  stripe_subscription_id text UNIQUE,
  tier text NOT NULL DEFAULT 'free' CHECK (tier IN ('free','pro','team')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active','past_due','canceled','trialing','incomplete')),
  current_period_end timestamptz,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.billing_usage_counters (
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  period_start date NOT NULL,  -- 月初固定 (= 月次リセット)
  ai_query_count int NOT NULL DEFAULT 0,
  ef_call_count int NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, period_start)
);

-- RLS: ユーザは自分の billing only / writes は service_role / EF 経由のみ
ALTER TABLE public.billing_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.billing_usage_counters ENABLE ROW LEVEL SECURITY;

CREATE POLICY billing_sub_self_read ON public.billing_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY billing_usage_self_read ON public.billing_usage_counters
  FOR SELECT USING (auth.uid() = user_id);
```

## 3. Edge Function 設計 (= 既存 hub 統合 / [EF-FIRST] [EF-CAP-50] 遵守)

### 既存 hub 拡張 案 (= 新規 EF 作らない / cap 49→49 維持)

**`schedule-hub`** に 2 action 追加:

| action | 入力 | 出力 | 用途 |
|---|---|---|---|
| `billing.create_checkout_session` | `tier: 'pro'\|'team'`, `return_url` | `{checkout_url}` | Flutter から Stripe Checkout へ遷移 |
| `billing.create_portal_session` | `return_url` | `{portal_url}` | 既 sub 解約・カード更新 |

### 新規 EF (= 1 本のみ / Webhook endpoint 専用 / cap 49→50)

**`stripe-webhook`** (= signature verification 必須 / [MCP-AUTH-27] #2 deny-by-default):

```typescript
// supabase/functions/stripe-webhook/index.ts
import Stripe from "https://esm.sh/stripe@14";
import { createClient } from "@supabase/supabase-js";

Deno.serve(async (req) => {
  const sig = req.headers.get("stripe-signature");
  if (!sig) return new Response("missing sig", { status: 400 });
  const body = await req.text();
  let event;
  try {
    event = stripe.webhooks.constructEvent(
      body, sig, Deno.env.get("STRIPE_WEBHOOK_SECRET")!,
    );
  } catch { return new Response("invalid sig", { status: 400 }); }

  switch (event.type) {
    case "checkout.session.completed":
      await upgradeToPro(event.data.object);
      break;
    case "customer.subscription.deleted":
      await downgradeToFree(event.data.object);
      break;
    case "invoice.payment_failed":
      await markPastDue(event.data.object);
      break;
  }
  return new Response("ok");
});
```

## 4. Flutter 側 (= 既存 `lib/services/` 拡張 / Win Codex)

### 新 service (= 1 file / 表示+操作のみ / [EF-FIRST] 遵守)

```dart
// lib/services/billing_service.dart
class BillingService {
  Future<String> createCheckoutSession({required String tier}) async {
    final res = await _supabase.functions.invoke(
      'schedule-hub',
      body: {'action': 'billing.create_checkout_session',
             'tier': tier,
             'return_url': _appReturnUrl},
    );
    return res.data['checkout_url'] as String;
  }

  Future<BillingSub> currentSubscription() async {
    final row = await _supabase
        .from('billing_subscriptions')
        .select()
        .eq('user_id', _userId)
        .maybeSingle();
    return BillingSub.fromJson(row ?? {'tier': 'free'});
  }
}
```

### UI (= 1 page / 既存 settings / WIP)

`lib/pages/billing_page.dart`: tier 比較 table + Upgrade button (= 既存 design system 流用 / [DESIGN] tokens)。

## 5. 受け入れ条件 mapping (= Issue #1305)

| # | 受け入れ条件 | 設計 mapping | 担当 |
|---|---|---|---|
| 1 | Flutter から Stripe Checkout 呼出可 | `BillingService.createCheckoutSession` + `url_launcher` | Win Codex |
| 2 | Supabase で利用回数 + sub 状態管理 | `billing_subscriptions` + `billing_usage_counters` table | Win Codex |
| 3 | Webhook で sub 完了時に Pro 昇格 | `stripe-webhook` EF + `upgradeToPro()` | Win Codex |

## 6. 9 原則チェック (= [PHILOSOPHY-22])

| # | 原則 | 該当 |
|---|---|---|
| 1 | CEO 感 | ✅ 自分株式会社の CFO 部署で billing 管理 (= Pro 化で CEO ARR 加算) |
| 2 | ミッション | ✅ 商品=価値検証加速 |
| 5 | 商品=価値 | ✅ Free→Pro 転換率 = 価値 signal |
| 7 | 資産負債 | ✅ ARR を CFO ledger に記録 (= [#1669](https://github.com/kanta13jp1/my_web_app/issues/1669) BudgetFinancialPlanner 接続) |
| 8 | KPI | ✅ MRR / churn / Free→Pro 転換率 |
| 9 | IPO | ✅ ARR 計上 (= 投資家説明可能) |

= **5/9 直接該当 / 7+/9 ✅ 閾値クリア**

## 7. 実装手順 (= Win Codex hand off)

1. `supabase/migrations/<ts>_create_billing_tables.sql` 起票 (= section 2)
2. `supabase/functions/schedule-hub/index.ts` に 2 action 追加 (= section 3)
3. `supabase/functions/stripe-webhook/` 新規 (= section 3)
4. `lib/services/billing_service.dart` 新規 (= section 4)
5. `lib/pages/billing_page.dart` 新規 + `/billing` route 追加
6. Stripe dashboard で Pro plan 設定 + Webhook URL 登録
7. `STRIPE_SECRET_KEY` / `STRIPE_WEBHOOK_SECRET` を Supabase secrets に追加

## 8. 次回拡張 (= part 143+)

- Team tier (= 5 seat)
- Annual billing (= 2 ヶ月分割引)
- Usage-based metered billing (= Pro 超過分 EF call)
- Stripe Tax 自動計算 (= 国別 VAT)

---

**Spec status**: 設計完了 / 実装ハンドオフ準備済 → cross-instance-pr 経由で Win Codex へ
