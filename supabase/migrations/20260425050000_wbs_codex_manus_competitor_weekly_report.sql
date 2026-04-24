update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added Manus weekly competitor reports%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added Manus weekly competitor reports. competitor-feature-sync can now generate and review competitor_report records from the latest competitor_feature data, including KGI/CSF/KPI, competitor summaries, and a Manus-style next action plan.'
  end
where id = 'bd663ded-3274-49a0-9de8-d1d4192bcfcf';
