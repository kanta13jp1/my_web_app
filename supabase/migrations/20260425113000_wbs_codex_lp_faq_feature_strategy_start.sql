update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 30),
  start_date = coalesce(start_date, date '2026-04-25'),
  description = case
    when coalesce(description, '') like '%Started 2026-04-25: Codex took over LP FAQ differentiation and FeatureStrategyAiReviewService test fix%'
      then description
    else coalesce(description, '') ||
      E'\n\nStarted 2026-04-25: Codex took over LP FAQ differentiation and FeatureStrategyAiReviewService test fix after confirming all [追加要望] user-request tasks were already completed.'
  end
where id = 'b9e41091-de8f-4a4e-ad2b-88be3bc003c4';
