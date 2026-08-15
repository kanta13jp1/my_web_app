-- Revenue-first follow-up: Supabase live Stripe secret and live webhook
-- signing secret have both been set. Await real supporter payment evidence.

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 95),
  remaining_work =
    'Mechanical gate stage: live_checkout_ready_for_real_payment. Supabase STRIPE_SECRET_KEY and live STRIPE_WEBHOOK_SECRET have both been updated, and supporter Checkout returns cs_live for 100 JPY. Stripe identity review/payout status still needs to clear before outreach and bank-payout completion.',
  recovery_plan =
    'Confirm Stripe account status is clear, then capture one real supporter/customer payment. Do not use self-payment as a live-mode test. After payment, verify hub_data with supabase/sql/first_supporter_webhook_evidence.sql.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 88),
  remaining_work =
    'Live Checkout and live webhook secret are ready. Remaining proof is a real paid checkout.session.completed webhook recorded as hub_data.source = stripe_supporter_payment.',
  recovery_plan =
    'After the first real payment, run supabase db query --linked --file supabase/sql/first_supporter_webhook_evidence.sql and require paid JPY evidence with checkout session and payment intent IDs.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Buyer outreach remains gated until Stripe identity review/payout status is clear. Checkout and live webhook secret are ready.',
  recovery_plan =
    'After Stripe account status clears, use docs/marketing/first-revenue-outreach.md for the first-buyer sprint and stop after one successful supporter payment.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 初回購入者獲得スプリント'
  AND status <> 'completed';
