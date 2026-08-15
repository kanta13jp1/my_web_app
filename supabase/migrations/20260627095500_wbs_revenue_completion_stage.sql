-- Revenue-first follow-up: persist the mechanical readiness stage so the WBS
-- mirrors the verifier output.

UPDATE public.wbs_tasks
SET
  remaining_work =
    'Mechanical gate stage: live_secret_required. Stripe account is enabled, but deployed supporter Checkout still returns cs_test. Rotate Supabase STRIPE_SECRET_KEY to sk_live via scripts/rotate_stripe_live_secret_and_check.ps1, then require scripts/check_first_revenue_readiness.py --mode live to pass with cs_live before promotion or real buyer outreach.',
  recovery_plan =
    'Run scripts/check_first_revenue_readiness.py --mode live --json after secret rotation. Expected stages: live_checkout_ready_for_real_payment, then paid_webhook_verified_waiting_for_bank_credit, then bank_credit_verified.',
  updated_at = now()
WHERE title IN (
    '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認',
    '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得'
  )
  AND status <> 'completed';
