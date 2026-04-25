update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-25'),
  end_date = date '2026-04-25',
  description = case
    when coalesce(description, '') like '%Completed 2026-04-25: Codex strengthened Harvey LP positioning%'
      then description
    else coalesce(description, '') ||
      E'\n\nCompleted 2026-04-25: Codex strengthened Harvey LP positioning. The landing-page feature card now names "Legal Management / Harvey AI" and presents Harvey as the legal-specialized backend for contract review, issue extraction, citation-backed checks, and legal memo drafting. FAQ now explains where Harvey AI is used.'
  end
where id in (
  '9e233cd9-c6e2-479c-b63a-6247851d7e02',
  '34b94a71-1b47-4f84-ac27-553e74b6f1c3'
);
