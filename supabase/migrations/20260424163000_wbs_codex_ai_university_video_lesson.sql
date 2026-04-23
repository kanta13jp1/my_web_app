update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added AI University avatar-video lessons%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added AI University avatar-video lessons. Added /ai-university-video, linked it from the AI University home card and main page, and passed title/voice/context through ai-hub video mode.'
  end
where id = '9fdbb725-c93f-46c4-93d9-927874c9be72';
