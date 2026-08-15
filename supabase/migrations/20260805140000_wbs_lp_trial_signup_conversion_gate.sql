-- Register the current landing-page conversion bottleneck as a revenue P0.
-- Production evidence on 2026-08-05 shows 456 unique landing visitors,
-- 6 trial users, 1 signup submit, and 0 verified signups. The implementation
-- is complete locally, but the task remains open until deployment and one
-- unrelated external user's completed signup are proven.
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
VALUES (
  'revenue / landing-conversion',
  'conversion_path',
  0,
  '[revenue-p0][landing-conversion] Reveal the save signup path immediately after trial',
  'After the anonymous trial returns value, automatically reveal the inline Magic Link save path on desktop and mobile without forcing keyboard focus. Judge success on verified signup and first action, not clicks alone.',
  'codex',
  'codex',
  'in_progress',
  80,
  DATE '2026-08-05',
  DATE '2026-08-06',
  'first-yen-revenue',
  'high',
  'pending',
  24,
  'Merge and deploy the CTA reveal fix, run production desktop/mobile QA, then prove at least one unrelated external user reaches verified signup and first action. Keep all A01-A10 statistical decisions insufficient_data until the per-arm report has real completed signups.',
  'If trials continue without signup submits, inspect CTA visibility and add an inline first-party Google save path. If submits occur without verified signups, audit Supabase redirect URLs, provider configuration, email delivery, and signup-completion event carryover before changing acquisition copy.',
  ARRAY[]::text[]
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

WITH lp_task AS (
  SELECT title
  FROM public.wbs_tasks
  WHERE title = '[revenue-p0][landing-conversion] Reveal the save signup path immediately after trial'
    AND instance = 'codex'
  LIMIT 1
)
UPDATE public.wbs_tasks AS downstream_task
SET
  depends_on_titles = CASE
    WHEN lp_task.title = ANY(
      COALESCE(downstream_task.depends_on_titles, ARRAY[]::text[])
    ) THEN downstream_task.depends_on_titles
    ELSE array_append(
      COALESCE(downstream_task.depends_on_titles, ARRAY[]::text[]),
      lp_task.title
    )
  END,
  updated_at = now()
FROM lp_task
WHERE downstream_task.title IN (
  '[revenue-p0][acquisition] Publish approved Hook B and measure the 3h/24h funnel',
  '[revenue-p0][bank-payout] Verify one external payment and at least JPY 1 bank deposit'
);
