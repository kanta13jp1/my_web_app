update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added Manus-like multi-step autopilot%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added Manus-like multi-step autopilot to AI Organization OS. A single objective can now be decomposed into requirement definition, KGI/CSF/KPI design, primary department execution, specialist review, and CEO review preparation, then delegated as agent_tasks with an executive board summary.'
  end
where id = 'c05a2010-d20d-4a91-bb78-03e3c0855acb';
