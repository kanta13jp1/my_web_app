-- Revenue-first growth follow-up:
-- improve the universal AI share feature so X impressions can convert into the
-- first real user without relying on acquaintances or warm contacts.

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
    'revenue-p0 / x-first-user-growth',
    'X',
    0,
    '[additional][revenue-p0][x-growth] AI share first-user acquisition mode',
    'Improve the universal AI share feature for X acquisition: UTM-tagged share URLs, first-user feedback copy, quick post presets, graceful text-only fallback when image generation fails, X intent fallback when X API posting is blocked by credits, and tests that protect the conversion path.',
    'codex',
    'codex',
    'in_progress',
    92,
    DATE '2026-06-27',
    DATE '2026-06-27',
    'first-yen-revenue',
    'high',
    'pending',
    6,
    'Use the deployed AI share dialog to publish/pin X posts, then confirm one X-origin user tried the site through UTM or analytics evidence.',
    'If OpenAI image generation remains blocked by billing limits or X API direct posting returns 402 credits errors, keep using the text-only X intent fallback. Do not block first-user acquisition on paid API limits.',
    ARRAY[]::text[]
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
  ai_review_status = EXCLUDED.ai_review_status,
  stale_threshold_hours = EXCLUDED.stale_threshold_hours,
  remaining_work = EXCLUDED.remaining_work,
  recovery_plan = EXCLUDED.recovery_plan,
  depends_on_titles = EXCLUDED.depends_on_titles,
  updated_at = now();
