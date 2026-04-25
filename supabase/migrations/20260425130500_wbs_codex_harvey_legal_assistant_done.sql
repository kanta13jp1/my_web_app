update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  start_date = coalesce(start_date, date '2026-04-25'),
  end_date = date '2026-04-25',
  description = case
    when coalesce(description, '') like '%Completed 2026-04-25: Codex added legal-assistant Harvey action aliases%'
      then description
    else coalesce(description, '') ||
      E'\n\nCompleted 2026-04-25: Codex added legal-assistant Harvey action aliases to tools-hub. legal.harvey.complete remains supported, and legal-assistant.harvey.complete / legal-assistant.review now route to the same HARVEY_API_KEY-backed completion flow. The legal compliance UI now calls the legal-assistant action name, and Issue #707 is covered by this implementation.'
  end
where id in (
  '8fda111d-7a5c-4a96-adc3-f6dd88180e23',
  '1609ead8-9c49-4985-b47d-4cc2f6b8468e'
);
