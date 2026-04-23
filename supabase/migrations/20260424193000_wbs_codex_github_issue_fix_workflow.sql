update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added github-issue-fix.yml%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added github-issue-fix.yml to select the next eligible open issue, create a repair branch and draft PR, and pair the lane with ci-auto-fix.yml for small CI self-healing commits.'
  end
where id = '577e1624-fca7-480d-9aea-21ee6aa1aa14';
