update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-24'),
  end_date = date '2026-04-24',
  priority = 'high',
  description = case
    when coalesce(description, '') like '%Done 2026-04-24: Codex added edge_llm.invoke%'
      then description
    else coalesce(description, '') ||
      E'\n\nDone 2026-04-24: Codex added edge_llm.invoke in ai-hub and shipped an Edge LLM Playground page for prompt/system/context JSON testing through Supabase Edge Functions.'
  end
where id = 'bdcb3105-543a-4e22-8448-73b878c0c091';
