-- Revenue-first follow-up: user-provided Stripe account-status screenshot
-- shows overdue identity verification and paused payouts.

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = LEAST(progress, 80),
  remaining_work =
    'Stripe account status shows an overdue required action: submit the representative identity verification document. Payouts are paused, and payments may be paused if unresolved. Complete this Stripe Dashboard task before buyer outreach, live payments, or bank-payout verification. The site Checkout also still returns cs_test until STRIPE_SECRET_KEY is rotated to a live key.',
  recovery_plan =
    'In Stripe Dashboard > Settings > Business > Account status, click 開始 for the overdue identity-verification task and submit valid representative documents. After the task moves to 完了 and payout pause is cleared, rerun scripts/rotate_stripe_live_secret_and_check.ps1 with sk_live... or a properly-permissioned rk_live... key, then require cs_live.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Do not start first-buyer outreach while Stripe identity verification is overdue, payouts are paused, or Checkout returns cs_test. Outreach opens only after Stripe account status is clear and scripts/check_first_revenue_readiness.py --mode live returns cs_live.',
  recovery_plan =
    'After Stripe identity verification and cs_live are confirmed, use docs/marketing/first-revenue-outreach.md for a 10-touch Founding Supporter sprint.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 初回購入者獲得スプリント'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Bank-credit verification cannot start while Stripe payouts are paused. Completion requires a real Stripe payout and redacted bank evidence showing credited_amount_jpy >= 1.',
  recovery_plan =
    'Clear Stripe identity verification first, then capture a live payment, verify webhook evidence, initiate or wait for payout, and validate redacted bank evidence with scripts/check_first_revenue_readiness.py --skip-checkout --require-bank.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 銀行口座への1円以上入金を確認'
  AND status <> 'completed';
