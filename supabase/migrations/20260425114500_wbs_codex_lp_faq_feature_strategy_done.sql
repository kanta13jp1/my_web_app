update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-25'),
  end_date = date '2026-04-25',
  description = case
    when coalesce(description, '') like '%Completed 2026-04-25: Codex added seven LP FAQ differentiation entries%'
      then description
    else coalesce(description, '') ||
      E'\n\nCompleted 2026-04-25: Codex added seven LP FAQ differentiation entries covering AI vendor diversification, life-capital waste reduction, KGI/CSF/KPI automation, habit gating, site guide chat, and NotebookLM handoff. FeatureStrategyAiReviewService tests were stabilized by asserting structured prompt facts instead of brittle localized prompt fragments.'
  end
where id = 'b9e41091-de8f-4a4e-ad2b-88be3bc003c4';
