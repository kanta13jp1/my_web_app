update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added AI University RLHF%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added AI University RLHF feedback. Learner reactions are captured as preference signals, scored as a Scale-style learning data quality dataset, exposed in the AI University provider UI, and summarized by ai-hub university.rlhf_snapshot for monitoring and improvement.'
  end
where id = 'dcecc10d-713b-4b1b-9839-0e0c08743ecf';

update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex synced already-closed GitHub Issue%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex synced already-closed GitHub Issue state back into WBS while processing the additional-request queue.'
  end
where id in (
  '48f9c0da-061d-462d-8ca1-44e186bd0675',
  '065b1a1b-c85a-4582-8d22-c27a9f51f88e'
);
