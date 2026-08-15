-- Keep the first-revenue WBS honest: live-secret work is active, while buyer
-- acquisition and bank-payout confirmation stay pending until their gates open.

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 80),
  remaining_work =
    'Stripe account is enabled, but the deployed supporter Checkout still returns cs_test. Rotate Supabase STRIPE_SECRET_KEY to sk_live via scripts/rotate_stripe_live_secret_and_check.ps1, then require scripts/check_first_revenue_readiness.py --mode live to pass with cs_live before promotion or real buyer outreach.',
  recovery_plan =
    'Do not paste secrets into chat. Run the local rotation helper, confirm cs_live, then proceed to one real supporter payment, webhook evidence, Stripe payout, and redacted bank-credit evidence.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = LEAST(GREATEST(progress, 65), 80),
  remaining_work =
    'Code and deployed Edge Functions can create a supporter Checkout session, but current production proof returns cs_test. After STRIPE_SECRET_KEY is rotated to sk_live, rerun scripts/check_first_revenue_readiness.py --mode live and require a cs_live session before considering this proven.',
  recovery_plan =
    'If cs_live fails after secret rotation, inspect Supabase function secrets and redeploy schedule-hub only if needed. After real payment, rerun with --require-webhook and service-role evidence.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'in_progress',
  progress = GREATEST(progress, 90),
  remaining_work =
    'Paid CTA and outreach copy are prepared, but public promotion must wait for the live Checkout gate to return cs_live.',
  recovery_plan =
    'Use docs/marketing/first-revenue-outreach.md only after cs_live. Keep claims honest: no fabricated customers, revenue, guarantees, or urgency.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] Founding Supporter 有料CTAを公開'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Blocked by stage gate, not by marketing work: wait until scripts/check_first_revenue_readiness.py --mode live returns cs_live. Then execute the 10-touch outreach sprint from docs/marketing/first-revenue-outreach.md.',
  recovery_plan =
    'After cs_live, publish one public post and send direct supporter requests to known contacts. Track concrete attempts and stop once the first successful payment is captured.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 初回購入者獲得スプリント'
  AND status <> 'completed';

UPDATE public.wbs_tasks
SET
  status = 'pending',
  progress = 0,
  remaining_work =
    'Not started because no live payment or Stripe payout exists yet. Completion requires redacted bank evidence showing credited_amount_jpy >= 1 and a matching Stripe payout ID or payout arrival date.',
  recovery_plan =
    'After the first paid Checkout and webhook evidence, initiate or wait for Stripe payout. Store only redacted evidence under evidence/ and verify it with scripts/check_first_revenue_readiness.py --skip-checkout --require-bank.',
  updated_at = now()
WHERE title = '[追加要望][収益化P0] 銀行口座への1円以上入金を確認'
  AND status <> 'completed';
