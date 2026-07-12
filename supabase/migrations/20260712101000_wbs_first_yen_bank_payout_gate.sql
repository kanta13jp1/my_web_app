-- Keep the revenue WBS honest: code readiness and real-world payout evidence
-- are separate gates. The goal remains open until an external buyer's payment
-- is recorded and at least JPY 1 reaches the configured bank account.

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
VALUES
  (
    'revenue / first-yen-funnel',
    'payments',
    0,
    '[revenue-p0][stripe-webhook] Reject unpaid Checkout and deduplicate Stripe events',
    'Require payment_status=paid before supporter revenue or subscription fulfillment, and use an atomic Stripe event ledger with safe retries.',
    'codex',
    'codex',
    'in_progress',
    90,
    DATE '2026-07-12',
    DATE '2026-07-12',
    'first-yen-webhook-hardening',
    'high',
    'pending',
    24,
    'Merge the PR, then verify the production database migration and stripe-webhook deployment before marking this task complete.',
    'If production deployment fails, inspect the database migration step before deploying stripe-webhook because the function depends on the event-ledger RPCs.',
    ARRAY[]::text[]
  ),
  (
    'revenue / first-yen-funnel',
    'payments',
    0,
    '[revenue-p0][bank-payout] Verify one external payment and at least JPY 1 bank deposit',
    'Acquire one buyer with no prior relationship through the X acquisition path, confirm a paid Founding Supporter event, confirm Stripe available balance and payout, then verify at least JPY 1 in the configured bank account.',
    'user',
    'user',
    'in_progress',
    40,
    DATE '2026-07-12',
    DATE '2026-07-20',
    'first-yen-revenue',
    'high',
    'pending',
    12,
    'Evidence still required: Stripe KYC and payout eligibility, one paid external-buyer webhook event, a Stripe payout record, and a matching bank deposit of at least JPY 1.',
    'If KYC is pending, complete only the requested Stripe verification. If reach is low, continue the daily X briefing A/B loop. If checkout succeeds but no revenue row appears, inspect stripe_webhook_events and hub_data before retrying. Do not use an operator self-payment or an acquaintance as the acquisition proof.',
    ARRAY[
      '[revenue-p0][stripe-webhook] Reject unpaid Checkout and deduplicate Stripe events',
      '[revenue-p0][first-yen] Attribute X growth experiments to supporter checkout and webhook evidence'
    ]::text[]
  )
ON CONFLICT (title, instance) DO UPDATE SET
  category = EXCLUDED.category,
  category_icon = EXCLUDED.category_icon,
  category_order = EXCLUDED.category_order,
  description = EXCLUDED.description,
  owner_instance = EXCLUDED.owner_instance,
  status = CASE
    WHEN public.wbs_tasks.status = 'completed' THEN 'completed'
    ELSE EXCLUDED.status
  END,
  progress = CASE
    WHEN public.wbs_tasks.status = 'completed' THEN 100
    ELSE EXCLUDED.progress
  END,
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  milestone_code = EXCLUDED.milestone_code,
  priority = EXCLUDED.priority,
  ai_review_status = EXCLUDED.ai_review_status,
  stale_threshold_hours = EXCLUDED.stale_threshold_hours,
  remaining_work = EXCLUDED.remaining_work,
  recovery_plan = EXCLUDED.recovery_plan,
  depends_on_titles = EXCLUDED.depends_on_titles,
  updated_at = now();
