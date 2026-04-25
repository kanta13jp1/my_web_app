update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 30),
  start_date = coalesce(start_date, date '2026-04-25'),
  description = case
    when coalesce(description, '') like '%Started 2026-04-25: Codex took over Harvey Legal AI genre%'
      then description
    else coalesce(description, '') ||
      E'\n\nStarted 2026-04-25: Codex took over Harvey Legal AI genre and Issue #709 mirror task. Existing Legal AI genre support was verified, and positioning copy will be strengthened so the AI University clearly presents Legal AI as a differentiated genre.'
  end
where id in (
  '0e5d0dac-7f8d-4bdf-bb2d-216370356007',
  '2e89d57c-ee16-464f-bbcb-8a3daf2a35d2'
);
