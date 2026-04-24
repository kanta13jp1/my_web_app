update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added official Manus task submission to my-ai-agent%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added official Manus task submission to my-ai-agent. The AI assistant chat can now choose Gemini or Manus for text responses; Manus uses MANUS_API_KEY to create an asynchronous task, returns task id/url, and stores provider metadata in my_agent_history.'
  end
where id = 'bce73b9c-417a-4b73-9819-cc9795dac379';
