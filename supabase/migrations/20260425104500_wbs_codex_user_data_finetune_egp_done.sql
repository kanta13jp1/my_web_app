update public.wbs_tasks
set
  owner_instance = 'codex',
  status = 'completed',
  progress = 100,
  end_date = date '2026-04-25',
  description = case
    when coalesce(description, '') like '%Completed 2026-04-25: Codex added the first-party user-data fine-tune readiness monitor%'
      then description
    else coalesce(description, '') ||
      E'\n\nCompleted 2026-04-25: Codex added the first-party user-data fine-tune readiness monitor. AI University RLHF signals and daily judgment quality evaluations are aggregated into KGI/CSF/KPI, eligible-record count, quality score, evaluation-batch readiness, fine-tune readiness, PII risk, export governance, and next action. The feature intentionally gates tuning behind de-identification and offline evaluation.'
  end
where id = 'b43c1fa4-6524-4c62-8762-5f2c60d165db';
