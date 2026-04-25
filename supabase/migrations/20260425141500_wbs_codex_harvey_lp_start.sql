update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 30),
  start_date = coalesce(start_date, date '2026-04-25'),
  description = case
    when coalesce(description, '') like '%Started 2026-04-25: Codex took over Harvey LP positioning%'
      then description
    else coalesce(description, '') ||
      E'\n\nStarted 2026-04-25: Codex took over Harvey LP positioning and Issue #708 mirror task. The landing page legal management message will be strengthened to present Harvey as the backend proof point for the legal workflow.'
  end
where id in (
  '9e233cd9-c6e2-479c-b63a-6247851d7e02',
  '34b94a71-1b47-4f84-ac27-553e74b6f1c3'
);
