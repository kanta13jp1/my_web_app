update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'in_progress',
  progress = greatest(progress, 30),
  start_date = coalesce(start_date, date '2026-04-25'),
  description = case
    when coalesce(description, '') like '%Started 2026-04-25: Codex took over Harvey legal-assistant EF%'
      then description
    else coalesce(description, '') ||
      E'\n\nStarted 2026-04-25: Codex took over Harvey legal-assistant EF and Issue #707 mirror task. Existing legal.harvey.complete support was verified, and compatibility action aliases are being added for legal-assistant callers.'
  end
where id in (
  '8fda111d-7a5c-4a96-adc3-f6dd88180e23',
  '1609ead8-9c49-4985-b47d-4cc2f6b8468e'
);
