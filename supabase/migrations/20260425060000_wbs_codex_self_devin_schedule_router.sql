update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added Self Devin Schedule%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added Self Devin Schedule. The scheduled workflow now routes pending WBS feature requests into the GitHub Issue repair lane, dispatches github-issue-fix.yml for open issues, completes WBS tasks whose linked issue is already closed, creates an issue when missing, and records schedule_task_runs as self-devin-schedule.'
  end
where id = '4358013c-85d1-43f8-a67b-0eb71a8655bb';
