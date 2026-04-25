update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 30),
  start_date = coalesce(start_date, date '2026-04-25'),
  description = case
    when coalesce(description, '') like '%Started 2026-04-25: Codex took over user-data fine-tune readiness%'
      then description
    else coalesce(description, '') ||
      E'\n\nStarted 2026-04-25: Codex took over user-data fine-tune readiness. Scope is to turn existing first-party feedback/evaluation signals into a Scale EGP-style dataset readiness monitor rather than launching an unsafe raw fine-tune job.'
  end
where id = 'b43c1fa4-6524-4c62-8762-5f2c60d165db';
