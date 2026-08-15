-- Revenue-first follow-up: make the current blocker explicit after live
-- Checkout and live webhook secret are ready.

INSERT INTO public.wbs_tasks
  (
    category,
    category_icon,
    category_order,
    title,
    description,
    instance,
    owner_instance,
    status,
    progress,
    start_date,
    end_date,
    milestone_code,
    priority,
    ai_review_status,
    stale_threshold_hours,
    remaining_work,
    recovery_plan,
    depends_on_titles
  )
VALUES
  (
    '追加要望 / business-revenue',
    '$',
    0,
    '[追加要望][収益化P0] Stripe本人確認・入金停止解除',
    'Stripe account-status task for the representative identity document must move to 完了, and payout pause/risk must clear before buyer outreach or bank-credit verification can honestly proceed.',
    'user',
    'user',
    'in_progress',
    50,
    DATE '2026-06-27',
    DATE '2026-06-28',
    'first-yen-revenue',
    'high',
    'pending',
    6,
    'Stripe account status previously showed the representative identity verification task under 要対応/審査中, with payouts paused or at risk. Confirm the task is 完了 and payouts are no longer paused.',
    'Open Stripe Dashboard > Settings > Business > Account status. Wait for the submitted identity document review to complete, then capture a screenshot or note that the task moved to 完了 and payout pause disappeared.',
    ARRAY['[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認']::text[]
  )
ON CONFLICT (title, instance) DO UPDATE SET
  category = EXCLUDED.category,
  category_icon = EXCLUDED.category_icon,
  category_order = EXCLUDED.category_order,
  description = EXCLUDED.description,
  owner_instance = EXCLUDED.owner_instance,
  status = CASE
    WHEN public.wbs_tasks.status = 'completed' THEN public.wbs_tasks.status
    ELSE EXCLUDED.status
  END,
  progress = GREATEST(public.wbs_tasks.progress, EXCLUDED.progress),
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  milestone_code = EXCLUDED.milestone_code,
  priority = EXCLUDED.priority,
  stale_threshold_hours = EXCLUDED.stale_threshold_hours,
  remaining_work = EXCLUDED.remaining_work,
  recovery_plan = EXCLUDED.recovery_plan,
  depends_on_titles = EXCLUDED.depends_on_titles,
  updated_at = now();

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 95),
  remaining_work =
    'Live Checkout and live webhook secret are ready. Remaining readiness blocker is Stripe identity review/payout status: confirm representative identity verification is 完了 and payout pause/risk is cleared before buyer outreach.',
  recovery_plan =
    'After Stripe account status clears, capture one real supporter/customer payment, verify hub_data via supabase/sql/first_supporter_webhook_evidence.sql, then wait for Stripe payout and bank-credit evidence.',
  depends_on_titles = ARRAY['[追加要望][収益化P0] Stripe本人確認・入金停止解除']::text[],
  updated_at = now()
WHERE title IN (
    '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認',
    '決済導入 (Stripe)'
  )
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Do not start buyer outreach while Stripe identity review/payout status is not confirmed clear. Checkout is live and webhook secret is live, but revenue operations are not complete until account status clears.',
  recovery_plan =
    'Once Stripe account status is clear, use docs/marketing/first-revenue-outreach.md for the Founding Supporter sprint. Do not claim existing customers or revenue.',
  depends_on_titles = ARRAY['[追加要望][収益化P0] Stripe本人確認・入金停止解除']::text[],
  updated_at = now()
WHERE title IN (
    '[追加要望][収益化P0] Founding Supporter 有料CTAを公開',
    '[追加要望][収益化P0] 初回購入者獲得スプリント'
  )
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Bank-credit verification is still not started. Requirements remain: real paid supporter Checkout, webhook evidence, Stripe payout, and redacted bank evidence showing credited_amount_jpy >= 1.',
  recovery_plan =
    'After first payment and payout, store only redacted bank evidence under evidence/ and verify with scripts/check_first_revenue_readiness.py --skip-checkout --require-bank.',
  depends_on_titles = ARRAY[
    '[追加要望][収益化P0] Stripe本人確認・入金停止解除',
    '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得'
  ]::text[],
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 銀行口座への1円以上入金を確認'
  AND status <> 'completed';
