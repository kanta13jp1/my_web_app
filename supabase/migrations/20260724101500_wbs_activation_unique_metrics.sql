-- Register the revenue-critical activation analytics task in the source-of-
-- truth WBS. It remains in progress until the production migration, app
-- tracker, and aggregate report have all been verified.
-- nocheck: time-relative
-- Replay-safe: the upsert always supplies a non-empty recovery_plan, and the
-- dependency update changes no deadline or recovery-plan fields.
UPDATE public.wbs_tasks
SET
  category = 'revenue / activation-to-paid',
  category_icon = 'analytics',
  category_order = 0,
  description = 'Deduplicate activation events by authenticated user, expose service-role-only 20-arm aggregates, and generate strict daily A01-A10 decision reports.',
  owner_instance = 'codex',
  status = CASE
    WHEN status = 'completed' THEN 'completed'
    ELSE 'in_progress'
  END,
  progress = CASE
    WHEN status = 'completed' THEN 100
    ELSE 95
  END,
  start_date = DATE '2026-07-24',
  end_date = DATE '2026-07-24',
  milestone_code = 'first-yen-revenue',
  priority = 'high',
  ai_review_status = 'pending',
  stale_threshold_hours = 24,
  remaining_work = 'Merge and deploy issue #4323, run the production activation experiment report, and attach the aggregate evidence before completion.',
  recovery_plan = 'If deployment fails, keep the daily app_analytics signal intact, inspect the activation_experiment_events migration, and rerun the aggregate report only after all 20 arms exist.',
  github_issue_url = 'https://github.com/kanta13jp1/my_web_app/issues/4323',
  github_issue_state = 'OPEN',
  github_issue_synced_at = now(),
  updated_at = now()
WHERE github_issue_number = 4323
  AND instance = 'codex'
  AND status <> 'completed';

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
  depends_on_titles,
  github_issue_number,
  github_issue_url,
  github_issue_state,
  github_issue_synced_at
)
SELECT
  'revenue / activation-to-paid',
  'analytics',
  0,
  '[revenue-p0][activation-analytics] Decide A01-A10 on unique users',
  'Deduplicate activation events by authenticated user, expose service-role-only 20-arm aggregates, and generate strict daily A01-A10 decision reports.',
  'codex',
  'codex',
  'in_progress',
  95,
  DATE '2026-07-24',
  DATE '2026-07-24',
  'first-yen-revenue',
  'high',
  'pending',
  24,
  'Merge and deploy issue #4323, run the production activation experiment report, and attach the aggregate evidence before completion.',
  'If deployment fails, keep the daily app_analytics signal intact, inspect the activation_experiment_events migration, and rerun the aggregate report only after all 20 arms exist.',
  ARRAY[]::text[],
  4323,
  'https://github.com/kanta13jp1/my_web_app/issues/4323',
  'OPEN',
  now()
WHERE NOT EXISTS (
  SELECT 1
  FROM public.wbs_tasks
  WHERE github_issue_number = 4323
    AND instance = 'codex'
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
  github_issue_number = EXCLUDED.github_issue_number,
  github_issue_url = EXCLUDED.github_issue_url,
  github_issue_state = EXCLUDED.github_issue_state,
  github_issue_synced_at = EXCLUDED.github_issue_synced_at,
  updated_at = now();

WITH activation_task AS (
  SELECT title
  FROM public.wbs_tasks
  WHERE github_issue_number = 4323
    AND instance = 'codex'
  ORDER BY
    CASE WHEN status <> 'completed' THEN 0 ELSE 1 END,
    updated_at DESC
  LIMIT 1
)
UPDATE public.wbs_tasks AS payout_task
SET
  depends_on_titles = CASE
    WHEN activation_task.title
      = ANY(COALESCE(payout_task.depends_on_titles, ARRAY[]::text[]))
      THEN payout_task.depends_on_titles
    ELSE array_append(
      COALESCE(payout_task.depends_on_titles, ARRAY[]::text[]),
      activation_task.title
    )
  END,
  updated_at = now()
FROM activation_task
WHERE payout_task.title =
  '[revenue-p0][bank-payout] Verify one external payment and at least JPY 1 bank deposit';
