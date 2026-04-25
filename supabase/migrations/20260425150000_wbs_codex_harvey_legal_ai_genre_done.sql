update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-25'),
  end_date = date '2026-04-25',
  description = case
    when coalesce(description, '') like '%Completed 2026-04-25: Codex strengthened the Legal AI genre positioning%'
      then description
    else coalesce(description, '') ||
      E'\n\nCompleted 2026-04-25: Codex strengthened the Legal AI genre positioning in AI University. The genre now explicitly frames Legal AI as a competitive white-space category, keeps Harvey as the launch provider, and expands focus areas to contract review, legal research, due diligence, and compliance.'
  end
where id in (
  '0e5d0dac-7f8d-4bdf-bb2d-216370356007',
  '2e89d57c-ee16-464f-bbcb-8a3daf2a35d2'
);
