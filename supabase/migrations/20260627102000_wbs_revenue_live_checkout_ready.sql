-- Revenue-first follow-up: Supabase STRIPE_SECRET_KEY was rotated to a live
-- key and the supporter Checkout readiness gate now returns cs_live.

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 92),
  remaining_work =
    'Mechanical gate stage: live_checkout_ready_for_real_payment. Supabase STRIPE_SECRET_KEY was rotated successfully and supporter Checkout now returns cs_live for 100 JPY. Before outreach, confirm Stripe identity review/payout status is clear and rotate STRIPE_WEBHOOK_SECRET to the live endpoint whsec if it has not been done.',
  recovery_plan =
    'Next: confirm the Stripe account-status task is 完了, set the live webhook signing secret if needed, then capture one real supporter payment and verify hub_data with supabase/sql/first_supporter_webhook_evidence.sql.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 85),
  remaining_work =
    'Live Checkout is ready: scripts/check_first_revenue_readiness.py --mode live returns cs_live. Remaining proof is a real paid checkout.session.completed webhook recorded as hub_data.source = stripe_supporter_payment.',
  recovery_plan =
    'Ensure STRIPE_WEBHOOK_SECRET matches the live Stripe webhook endpoint, then after payment run supabase db query --linked --file supabase/sql/first_supporter_webhook_evidence.sql and require paid JPY evidence.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Buyer outreach remains gated until Stripe identity review/payout status is clear and live webhook signing secret is confirmed. Checkout itself is now live.',
  recovery_plan =
    'After those gates clear, use docs/marketing/first-revenue-outreach.md for the first-buyer sprint and stop after one successful supporter payment.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 初回購入者獲得スプリント'
  AND status <> 'completed';
