-- Revenue-first follow-up: clarify the accepted Stripe live key formats after
-- the first local rotation attempt rejected a non-secret key.

UPDATE public.wbs_tasks
SET
  remaining_work =
    'Mechanical gate stage: live_secret_required. The previous rotation attempt supplied a value that was not a server-side live Stripe secret. Use sk_live..., STRIPE_SECRET_KEY=sk_live..., or a properly-permissioned rk_live... restricted key; do not use pk_live... publishable keys. Then rerun scripts/rotate_stripe_live_secret_and_check.ps1 and require cs_live before promotion or real buyer outreach.',
  recovery_plan =
    'Copy the live secret from Stripe Developers > API keys. If using a restricted key, grant the Checkout/customer/payment permissions required by schedule-hub. Keep the key out of chat and shell history, then rerun the mechanical gate.',
  updated_at = now()
WHERE title IN (
    '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認',
    '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得'
  )
  AND status <> 'completed';
