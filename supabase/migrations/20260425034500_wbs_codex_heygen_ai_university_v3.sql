update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex upgraded AI University video lessons with a HeyGen v3 plan%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex upgraded AI University video lessons with a HeyGen v3 plan. Each selected lesson now produces a HeyGen Avatar V brief, five-scene storyboard, localization notes, copyable production prompt, and generation prompt optimized for short multilingual avatar lessons.'
  end
where id = 'd0465d8b-9bca-4d71-b0e3-d12d7f126ba1';
