-- Reconcile the revenue WBS with the proven July funnel state.
-- The bank-deposit goal remains open. Hook B still needs explicit owner
-- approval, and Stripe charge/payout readiness needs fresh machine evidence.
-- A JPY 500 live HexCiv purchase on 2026-07-29 proved the checkout, webhook,
-- and download path, but the purchaser is an administrator. It is therefore
-- self-test evidence only and must not count as external-user revenue.
-- nocheck: time-relative

-- Keep github_issue_* unset for these split tasks. Production enforces one
-- active WBS row per (github_issue_number, instance), and issue #3639 remains
-- attached to the parent bank-payout task.

UPDATE public.wbs_milestones
SET
  target_date = DATE '2026-08-07',
  description = 'Publish the approved outcome-first acquisition experiment, acquire one unrelated external buyer, verify a paid Stripe event, then prove at least JPY 1 reached the configured bank account.'
WHERE code = 'first-yen-revenue';

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
    'verified',
    0,
    '[revenue-p0][stripe-account] Automate live charge and payout readiness evidence',
    'Expose a service-role-only redacted Stripe account readiness action and a strict manual workflow that proves charges_enabled and payouts_enabled without copying secret keys into GitHub.',
    'codex',
    'codex',
    'in_progress',
    95,
    DATE '2026-07-31',
    DATE '2026-07-31',
    'first-yen-revenue',
    'high',
    'pending',
    24,
    'Merge and deploy the readiness action, then run Stripe Account Readiness with both strict gates enabled and attach the redacted artifact to issue #3639.',
    'If the restricted Stripe key cannot read the account object, grant it Accounts read permission or rotate to an appropriate live key. Never print or commit the key.',
    ARRAY[]::text[]
  ),
  (
    'revenue / first-yen-funnel',
    'campaign',
    0,
    '[revenue-p0][acquisition] Publish approved Hook B and measure the 3h/24h funnel',
    'After exact owner approval, publish the outcome-first X parent post with no URL and add the measured landing URL in one reply. Keep media, CTA, and attribution fixed through the 24-hour readout.',
    'user',
    'user',
    'in_progress',
    90,
    DATE '2026-07-31',
    DATE '2026-08-01',
    'first-yen-revenue',
    'high',
    'pending',
    12,
    'Obtain the exact public-post approval, publish candidate 6203a344-55bd-44a0-b4ba-ab191f6fb9a2 once, then record 3h/24h impressions, clicks, landing views, signups, first actions, checkout starts, and paid events.',
    'Do not publish without exact owner approval. If 24-hour clicks remain zero, change only the hook for the next experiment; do not add irrelevant trends, fabricated news, DMs, follows, or acquaintances.',
    ARRAY[]::text[]
  ),
  (
    'revenue / first-yen-funnel',
    'verified_user',
    0,
    '[revenue-p0][payment-evidence] Exclude admin and unclassified supporter payments',
    'Classify optional authenticated buyers on the server, copy the classification through Stripe metadata and the signed webhook, and count only measured first_user_growth payments from signed-in non-admin users in PII-free revenue evidence.',
    'codex',
    'codex',
    'in_progress',
    90,
    DATE '2026-08-05',
    DATE '2026-08-05',
    'first-yen-revenue',
    'high',
    'pending',
    24,
    'Merge and deploy schedule-hub, stripe-webhook, and growth-hub. Then verify a paid authenticated_non_admin supporter record joins the X signup and first-action ledger while admin_self and anonymous_unclassified records remain excluded.',
    'Keep anonymous checkout available, but never count anonymous, admin, legacy unclassified, or non-first_user_growth payments as the external-buyer proof. Use the PII-free evidence SQL instead of exposing email, UUID, or full Stripe identifiers.',
    ARRAY[
      '[revenue-p0][stripe-account] Automate live charge and payout readiness evidence',
      '[revenue-p0][acquisition] Publish approved Hook B and measure the 3h/24h funnel'
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

UPDATE public.wbs_tasks
SET
  status = 'completed',
  progress = 100,
  remaining_work = 'None. The 20 landing arms and unique-user A01-A10 report were merged, deployed, and verified in production; the result remains insufficient_data until external traffic arrives.',
  recovery_plan = 'Reopen only if the unique-user experiment report regresses or any of the 20 arms disappears.',
  github_issue_state = 'CLOSED',
  github_issue_synced_at = now(),
  updated_at = now()
WHERE github_issue_number = 4323
  AND instance = 'codex';

UPDATE public.wbs_tasks AS payout_task
SET
  depends_on_titles = (
    SELECT ARRAY(
      SELECT DISTINCT dependency
      FROM unnest(
        COALESCE(payout_task.depends_on_titles, ARRAY[]::text[]) ||
        ARRAY[
          '[revenue-p0][stripe-account] Automate live charge and payout readiness evidence',
          '[revenue-p0][acquisition] Publish approved Hook B and measure the 3h/24h funnel',
          '[revenue-p0][payment-evidence] Exclude admin and unclassified supporter payments'
        ]::text[]
      ) AS dependencies(dependency)
      ORDER BY dependency
    )
  ),
  remaining_work = 'Fresh evidence required: Stripe charges_enabled=true and payouts_enabled=true, exact approval and publication of Hook B, one unrelated external signup and first action, one paid authenticated_non_admin first_user_growth webhook, one Stripe payout, and a matching bank deposit of at least JPY 1. Exclude the 2026-07-29 JPY 500 HexCiv purchase because its purchaser is_admin=true and role=admin; it proves only the checkout, webhook, and download path.',
  recovery_plan = 'Run the strict Stripe readiness workflow first. Publish Hook B only after exact owner approval. If traffic arrives without signup, inspect the selected landing arm. Count only a signed-in non-admin payment joined to the measured X signup and first action; manually confirm the buyer is not an acquaintance, then inspect Stripe payout status and a redacted bank statement.',
  end_date = DATE '2026-08-07',
  updated_at = now()
WHERE payout_task.title =
  '[revenue-p0][bank-payout] Verify one external payment and at least JPY 1 bank deposit'
  AND payout_task.status <> 'completed';
