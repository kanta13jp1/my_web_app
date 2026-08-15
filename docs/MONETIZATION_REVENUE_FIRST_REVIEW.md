# Revenue-First Monetization Review

Date: 2026-06-27 JST

## Goal

The session goal is not "add monetization code". The goal is verified bank
credit of at least 1 JPY from this site.

## Current Stage

`scripts/check_first_revenue_readiness.py --mode live --json` now passes with a
`cs_live...` Founding Supporter Checkout session for 100 JPY.

Current mechanical stage:

```text
live_checkout_ready_for_real_payment
```

This is progress, not completion. No real payment, webhook payment evidence,
Stripe payout, or bank statement credit has been confirmed yet.

## Registered P0 Chain

The linked WBS now has the `first-yen-revenue` milestone and these top-priority
tasks:

1. `[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認`
2. `[追加要望][収益化P0] Stripe本人確認・入金停止解除`
3. `[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得`
4. `[追加要望][収益化P0] Founding Supporter 有料CTAを公開`
5. `[追加要望][収益化P0] 初回購入者獲得スプリント`
6. `[追加要望][収益化P0] 銀行口座への1円以上入金を確認`

Additional first-user acquisition P0 tasks were added because revenue will not
arrive without at least one real user/supporter candidate:

1. `[追加要望][収益化P0][1人目獲得] 最初の対象ユーザー像と10名リストを作る`
2. `[追加要望][収益化P0][1人目獲得] 1対1アウトリーチ10件を実施`
3. `[追加要望][収益化P0][1人目獲得] 公開投稿1本と導線クリックを確認`
4. `[追加要望][収益化P0][1人目獲得] 初回ユーザーの利用証跡とヒアリングを取得`
5. `[追加要望][収益化P0][1人目獲得] Stripe解除後に初回支援決済へ転換`

The user explicitly rejected warm-contact acquisition. X-specific P0 tasks now
target `https://x.com/kanta13jp1`:

1. `[追加要望][収益化P0][X集客] プロフィールを1人目ユーザー獲得用に改修`
2. `[追加要望][収益化P0][X集客] 固定ポストをサイト導線に差し替え`
3. `[追加要望][収益化P0][X集客] 7日間・1日5投稿のインプレッション実験`
4. `[追加要望][収益化P0][X集客] 大きめアカウントへの有益リプライ30件`
5. `[追加要望][収益化P0][X集客] Xアナリティクスで勝ち投稿を増幅`
6. `[追加要望][収益化P0][X集客] X経由の1人利用を確認`

The pre-existing `決済導入 (Stripe)` task is also linked to the first-revenue
milestone and now reflects that live Checkout and the live webhook secret are
ready.

## Source Findings

- `lib/pages/subscription_billing_page.dart` exposes Free / Pro / Team UI and a
  public Founding Supporter CTA.
- `lib/services/billing_service.dart` calls `schedule-hub` billing actions.
- `supabase/functions/schedule-hub/index.ts` creates Stripe Checkout sessions,
  Billing Portal sessions, and the public
  `billing.create_supporter_checkout_session` action.
- `supabase/functions/stripe-webhook/index.ts` verifies Stripe signatures and
  records completed supporter payments into `hub_data` with
  `source = stripe_supporter_payment`.
- `supabase/sql/first_supporter_webhook_evidence.sql` reads the latest supporter
  payment evidence after a real payment.
- `scripts/check_first_revenue_readiness.py` is the mechanical gate for live
  Checkout, optional webhook evidence, and optional redacted bank evidence.
- `scripts/rotate_stripe_live_secret_and_check.ps1` safely rotates
  `STRIPE_SECRET_KEY` and optionally `STRIPE_WEBHOOK_SECRET` without placing
  secrets in chat or shell history.
- `docs/marketing/first-user-acquisition-sprint.md` now provides a concrete
  10-touch sprint to get the first real user or supporter candidate. It starts
  with free usage/feedback while paid conversion remains gated by Stripe payout
  status.
- `docs/marketing/x-impression-growth-sprint.md` now provides the X-only growth
  sprint: profile rewrite, pinned post, 7-day posting cadence, 30 useful replies
  to larger accounts, analytics tracking, and one X-origin user evidence.

## Current Evidence

- Supabase `STRIPE_SECRET_KEY` has been rotated to a live key.
- Supabase `STRIPE_WEBHOOK_SECRET` has been rotated to a live `whsec...`.
- Live supporter Checkout returns `cs_live...` for 100 JPY.
- `supabase/sql/first_supporter_webhook_evidence.sql` currently returns no rows,
  which is expected before a real payment.
- User-provided Stripe dashboard screenshots showed the representative identity
  verification task under review / required and payout pause risk. Treat that
  as the current external blocker until the account-status task is `完了` and
  payouts are not paused.
- Stripe dashboard metrics shown by the user were still zero for revenue, JPY
  balance, customers, and active subscriptions.

## External Reality Check

- Stripe JPY is a zero-decimal currency.
- Stripe's non-zero minimum charge for JPY is 50 JPY.
- Stripe's Japan minimum payout amount is 1 JPY.
- Japan payouts are not daily by default; the default schedule is manual.

Sources:

- Stripe supported currencies: https://docs.stripe.com/currencies
- Stripe payouts: https://docs.stripe.com/payouts
- Stripe payout schedule note for Japan:
  https://stripe.com/resources/more/payouts-explained

Therefore the smallest practical path is not a literal 1 JPY charge. It is:

1. Clear Stripe identity verification and payout pause risk.
2. Capture one real supporter/customer payment of at least 50 JPY.
3. Confirm Stripe webhook evidence in `hub_data`.
4. Initiate or wait for Stripe payout.
5. Confirm bank statement credit of at least 1 JPY.

## Verification Gates

Live Checkout:

```powershell
C:\Users\kanta\AppData\Local\Programs\Python\Python312\python.exe scripts\check_first_revenue_readiness.py --mode live --json
```

Webhook evidence after real payment:

```powershell
supabase db query --linked --file supabase\sql\first_supporter_webhook_evidence.sql --output json
```

Bank evidence after payout:

```powershell
C:\Users\kanta\AppData\Local\Programs\Python\Python312\python.exe scripts\check_first_revenue_readiness.py --skip-checkout --require-bank --bank-evidence evidence\first-revenue-bank-credit.redacted.json --json
```

The bank evidence JSON must show `credited_amount_jpy >= 1`, a statement date,
and a Stripe payout ID or payout arrival date. Do not store unredacted bank
statements in the repository.

## Promotion Rule

Do not start broad outreach while Stripe account status still shows identity
review, overdue identity verification, payout pause, or payout pause risk.

After Stripe account status clears, use
`docs/marketing/first-revenue-outreach.md` for the first-buyer sprint. Live-mode
self-payment is not acceptable as the revenue proof; capture a real supporter or
customer payment.

Before paid outreach, run `docs/marketing/x-impression-growth-sprint.md` to get
one real X-origin user or supporter candidate. Anonymous page views,
self-testing, and bot traffic do not count.

## Completion Rule

Do not mark the session goal complete from:

- `cs_live...` alone
- Stripe balance alone
- a successful webhook alone
- a pending payout alone

The completion evidence is a bank statement credit of at least 1 JPY, with a
matching Stripe payout ID or payout arrival date.
