-- Revenue-first growth optimizer:
-- register automated X post metric monitoring and A/B feedback as a P0 task.
-- This supports the active first-yen revenue goal by improving reach until at
-- least one real X-origin user tries the site and can later convert to payment.

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
  '追加要望 / x-10k-ab-optimizer',
  'query_stats',
  0,
  '[追加要望][収益化P0][X集客][10K] X投稿メトリクス監視・A/B自動改善ループを本番化',
  'Collect impressions and engagement metrics for X posts created by AI share, store snapshots, compare variants such as Daily Briefing, link-in-reply, media/no-media, and feed the winning pattern back into the next AI share prompt.',
  'codex',
  'codex',
  'in_progress',
  85,
  DATE '2026-06-27',
  DATE '2026-06-28',
  'first-yen-revenue',
  'high',
  'pending',
  6,
  'Deploy growth-hub with x.metrics_collect and x.performance_context, add a scheduled GitHub Actions collector, confirm at least one x_post_metric_snapshot row appears, then use the learned winner to publish the next 10K-target post.',
  'If X non-public impression metrics are unavailable, fall back to public engagement metrics and manual X Analytics screenshots. Keep the Daily Briefing format as the baseline and A/B test only one variable at a time.',
  ARRAY[
    '[追加要望][収益化P0][X集客][10K] Xトレンド連動デイリーブリーフィング生成を本番化',
    '[追加要望][収益化P0][X集客][10K] 10Kインプレッション狙いのブリーフィング投稿を7日実行',
    '[追加要望][収益化P0][X集客][CVR] X流入5分フィードバック捕捉を本番化'
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
  progress = GREATEST(progress, 85),
  remaining_work =
    'Automated X post metric monitoring is being added: collect post/reply metrics, store latest_metrics on x_post_log, create x_post_metric_snapshot rows, and feed the winning A/B pattern back into AI share generation.',
  depends_on_titles = array_remove(array_cat(coalesce(depends_on_titles, ARRAY[]::text[]), ARRAY[
    '[追加要望][収益化P0][X集客][10K] X投稿メトリクス監視・A/B自動改善ループを本番化'
  ]::text[]), NULL),
  updated_at = now()
WHERE milestone_code = 'first-yen-revenue'
  AND title IN (
    '[追加要望][収益化P0][X集客][10K] Xトレンド連動デイリーブリーフィング生成を本番化',
    '[追加要望][収益化P0][X集客][10K] 10Kインプレッション狙いのブリーフィング投稿を7日実行',
    '[追加要望][収益化P0][X集客][CVR] X流入5分フィードバック捕捉を本番化',
    '[追加要望][収益化P0][X集客] Xアナリティクスで勝ち投稿を増幅'
  )
  AND status <> 'completed';
