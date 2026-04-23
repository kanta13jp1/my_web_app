update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added a Self Devin control tower%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added a Self Devin control tower to Admin Analytics so the four Claude Code lanes, automation loops, feature-request load, and next rescue action are visible in one place. The schedule monitor was also expanded to include github-issue-fix and ci-auto-fix.'
  end
where title = '[追加要望] ゴール: Claude Code 4インスタンスを「自社Devin」として機能させる';
