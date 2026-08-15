-- Revenue-first follow-up: record the current live-readiness blocker and the
-- safe local helper for rotating the Stripe live secret.

UPDATE public.wbs_tasks
SET
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = CASE WHEN status = 'completed' THEN progress ELSE GREATEST(progress, 80) END,
  remaining_work =
    'Stripe account is enabled, but the deployed supporter Checkout still returns cs_test. Rotate Supabase STRIPE_SECRET_KEY to sk_live via scripts/rotate_stripe_live_secret_and_check.ps1, then require scripts/check_first_revenue_readiness.py --mode live to pass with cs_live before promotion or real buyer outreach.',
  recovery_plan =
    'Do not paste secrets into chat. Run the local rotation helper, confirm cs_live, then proceed to one real supporter payment, webhook evidence, Stripe payout, and redacted bank-credit evidence.',
  updated_at = now()
WHERE milestone_code = 'first-yen-revenue'
  AND status <> 'completed'
  AND (
    description ILIKE '%Stripe%'
    OR remaining_work ILIKE '%Stripe%'
    OR title ILIKE '%Stripe%'
  );

UPDATE public.wbs_tasks
SET
  status = CASE WHEN status = 'completed' THEN status ELSE 'pending' END,
  progress = CASE WHEN status = 'completed' THEN progress ELSE progress END,
  remaining_work =
    'Wait until the live Checkout gate returns cs_live. After that, use docs/marketing/first-revenue-outreach.md for a 10-touch first-buyer sprint. Stop once the first successful payment is captured and move to webhook and bank payout verification.',
  recovery_plan =
    'If organic traffic is insufficient after cs_live, publish the prepared Founding Supporter copy through approved channels or manually send the direct-message draft to known contacts. Do not claim existing revenue or customers.',
  updated_at = now()
WHERE milestone_code = 'first-yen-revenue'
  AND status <> 'completed'
  AND (
    description ILIKE '%Supporter%'
    OR description ILIKE '%CTA%'
    OR description ILIKE '%purchase%'
    OR recovery_plan ILIKE '%social%'
  );
