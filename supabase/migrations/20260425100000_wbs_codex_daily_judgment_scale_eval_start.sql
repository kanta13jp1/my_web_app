update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 10),
  start_date = coalesce(start_date, date '2026-04-24'),
  description = case
    when coalesce(description, '') like '%Started 2026-04-24: Codex took over daily-judgment Scale evaluation%'
      then description
    else coalesce(description, '') ||
      E'\n\nStarted 2026-04-24: Codex took over daily-judgment Scale evaluation so generated decisions can be automatically scored before users rely on them.'
  end
where id = '6a1d4235-a588-4637-9264-628d3726e928';
