update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added HeyGen blog video conversion%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added HeyGen blog video conversion to the tech blog tracker. Schedule-generated blog drafts can now expand into a copyable HeyGen Avatar V production brief, five-scene storyboard, short SNS post, and reuse checklist for X, YouTube Shorts, and LinkedIn.'
  end
where id = 'cd7bb5cb-b3a7-49ce-8fc7-db1f943447c2';
