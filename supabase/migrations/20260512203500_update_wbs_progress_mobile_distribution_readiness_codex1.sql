-- Codex #1: Issue #1495 mobile distribution readiness slice.
--
-- This records the deterministic signing/store secret readiness gate that
-- complements the existing mobile build artifact workflow.

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 55),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Codex #1 added a mobile distribution readiness gate. Remaining work: configure Android/iOS signing and store distribution secrets, run the strict manual gate, then perform user-approved Play Internal testing and TestFlight uploads.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #1 / 2026-05-12] Issue #1495 advanced: added a mobile distribution readiness workflow/report that checks signing placeholders, docs, workflow wiring, and Android/iOS store secret presence without exposing secret values.'
WHERE github_issue_number = 1495;

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'Codex #1: mobile distribution readiness gate (#1495)',
  'Added a deterministic GitHub Actions gate and JSON report for iOS/Android distribution readiness, including signing/store secret presence checks, workflow wiring checks, and runbook updates.',
  '2026-05-12'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'Codex #1: mobile distribution readiness gate (#1495)'
);
