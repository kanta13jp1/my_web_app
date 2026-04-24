update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added daily-judgment Scale evaluation%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added daily-judgment Scale evaluation. ai-hub judgment.get now normalizes the AI judgment into KGI/CSF/KPI fields, scores the response with a Scale-style rubric, stores quality snapshots for logged-in users, and exposes the quality gate in the Daily Judgment UI.'
  end
where id = '6a1d4235-a588-4637-9264-628d3726e928';
