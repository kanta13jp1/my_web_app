-- Revenue-first conversion bridge:
-- add a P0 WBS task for turning X impressions into observable first-user
-- feedback before asking for payment.

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
  '追加要望 / revenue-x-cvr',
  'ads_click',
  0,
  '[追加要望][収益化P0][X集客][CVR] X流入5分フィードバック捕捉を本番化',
  'Show a lightweight feedback CTA only for visitors arriving through utm_source=x and utm_campaign=first_user_growth, record A/B/C preference signals, and offer an X intent reply so high-impression posts can produce real user evidence.',
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
  'Deploy the landing CTA, confirm x_first_user_* acquisition signals appear in app_analytics.source_details, then use the best X briefing thread to drive one visible user reply or DM.',
  'If visitors click but do not reply, reduce the CTA to one question and pin the best briefing thread with the same A/B/C ask. Do not ask for payment until Stripe payout status is clear.',
  ARRAY[
    '[追加要望][収益化P0][X集客][10K] 10Kインプレッション狙いのブリーフィング投稿を7日実行',
    '[追加要望][収益化P0][X集客][10K] 勝ち投稿から1人目ユーザー導線へ転換'
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
  progress = GREATEST(progress, 70),
  remaining_work =
    'Use the X first-user feedback CTA to convert high-impression briefing traffic into recorded A/B/C preference signals and at least one visible real-user reply, DM, or feedback screenshot.',
  depends_on_titles = array_remove(array_cat(coalesce(depends_on_titles, ARRAY[]::text[]), ARRAY[
    '[追加要望][収益化P0][X集客][CVR] X流入5分フィードバック捕捉を本番化'
  ]::text[]), NULL),
  updated_at = now()
WHERE milestone_code = 'first-yen-revenue'
  AND title IN (
    '[追加要望][収益化P0][X集客] X経由の1人利用を確認',
    '[追加要望][収益化P0][X集客][10K] 勝ち投稿から1人目ユーザー導線へ転換'
  )
  AND status <> 'completed';
