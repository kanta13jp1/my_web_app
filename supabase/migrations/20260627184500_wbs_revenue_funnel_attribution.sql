-- Revenue-first P0:
-- connect X growth experiments to first supporter payment evidence.

INSERT INTO public.wbs_tasks (
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
VALUES (
  'revenue / first-yen-funnel',
  'payments',
  0,
  '[revenue-p0][first-yen] Attribute X growth experiments to supporter checkout and webhook evidence',
  'Create a public Founding Supporter one-time Stripe Checkout, pass X UTM/A-B metadata into Stripe, record checkout.session.completed as hub_data.source=stripe_supporter_payment, and expose a revenue.funnel_report for the first-yen revenue sprint.',
  'codex',
  'codex',
  'in_progress',
  90,
  DATE '2026-06-27',
  DATE '2026-06-28',
  'first-yen-revenue',
  'high',
  'pending',
  6,
  'One real supporter payment and Stripe bank payout evidence are still required before this goal can be marked complete.',
  'If checkout creation or webhook evidence fails, first verify STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, the live webhook endpoint, and supabase/sql/first_supporter_webhook_evidence.sql. If there is reach but no conversion, keep A/B testing X Daily Briefing variants and route CTA links through the billing page with UTM metadata.',
  ARRAY[
    '[revenue-p0][first-yen] X post metrics A/B optimizer toward 10K impressions'
  ]::text[]
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
  progress = GREATEST(progress, 90),
  remaining_work =
    'Automated X metric monitoring is live. Next: capture one real Founding Supporter payment, verify stripe_supporter_payment webhook evidence, then verify Stripe bank payout evidence.',
  depends_on_titles = array_remove(array_cat(coalesce(depends_on_titles, ARRAY[]::text[]), ARRAY[
    '[revenue-p0][first-yen] Attribute X growth experiments to supporter checkout and webhook evidence'
  ]::text[]), NULL),
  updated_at = now()
WHERE milestone_code = 'first-yen-revenue'
  AND status <> 'completed';
