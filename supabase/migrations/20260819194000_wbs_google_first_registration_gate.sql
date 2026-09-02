-- Register the authentication handoff that currently blocks the first
-- unrelated external user from reaching activation and checkout.
-- nocheck: time-relative

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
    'revenue / landing-auth',
    'conversion_path',
    0,
    '[revenue-p0][landing-auth] Make Google OAuth primary and diagnose every auth handoff',
    'Use the already-enabled Google provider as the first registration path. Keep Magic Link as a recoverable fallback, preserve the anonymous AI result across OAuth, and record only aggregate attempt/success/failure categories without PII.',
    'codex',
    'codex',
    'in_progress',
    85,
    DATE '2026-08-19',
    DATE '2026-08-20',
    'first-yen-revenue',
    'high',
    'pending',
    24,
    'Merge and deploy the Google-first registration patch, pass desktop/mobile production QA, then verify one unrelated external user reaches non-anonymous signup completion and first action. Do not count OAuth launch alone as a signup.',
    'If Google OAuth does not return, inspect the Supabase and Google callback allowlists and the aggregate failure counters. If OAuth returns but activation does not, inspect pending signup attribution and onboarding restoration without exporting user identifiers.',
    ARRAY['[revenue-p0][landing-conversion] Reveal the save signup path immediately after trial']::text[]
  ),
  (
    'revenue / landing-auth',
    'alternate_email',
    0,
    '[revenue-p0][landing-auth] Configure custom SMTP and verify an external Magic Link',
    'The Supabase custom SMTP switch is currently off. Configure a verified sending domain and provider credentials only after owner approval, then verify delivery to one non-owner external mailbox without storing the address in WBS or analytics.',
    'codex',
    'codex',
    'pending',
    10,
    DATE '2026-08-19',
    DATE '2026-08-22',
    'first-yen-revenue',
    'high',
    'pending',
    72,
    'Owner selects or approves an SMTP provider, verifies the sending domain, and supplies credentials through Supabase secrets/settings. Then run one consented external delivery test and confirm Magic Link send plus inbox open using aggregate counters.',
    'Google OAuth remains the production registration path while SMTP is unavailable. Do not purchase a provider, change DNS, or expose credentials without explicit owner approval.',
    ARRAY['[revenue-p0][landing-auth] Make Google OAuth primary and diagnose every auth handoff']::text[]
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

WITH auth_task AS (
  SELECT title
  FROM public.wbs_tasks
  WHERE title = '[revenue-p0][landing-auth] Make Google OAuth primary and diagnose every auth handoff'
    AND instance = 'codex'
  LIMIT 1
)
UPDATE public.wbs_tasks AS downstream_task
SET
  depends_on_titles = CASE
    WHEN auth_task.title = ANY(
      COALESCE(downstream_task.depends_on_titles, ARRAY[]::text[])
    ) THEN downstream_task.depends_on_titles
    ELSE array_append(
      COALESCE(downstream_task.depends_on_titles, ARRAY[]::text[]),
      auth_task.title
    )
  END,
  updated_at = now()
FROM auth_task
WHERE downstream_task.title IN (
  '[revenue-p0][acquisition] Publish approved Hook B and measure the 3h/24h funnel',
  '[revenue-p0][bank-payout] Verify one external payment and at least JPY 1 bank deposit'
);
