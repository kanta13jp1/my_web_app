-- Codex #3 / 2026-05-03: complete Issue #1606 NotebookLM list diff gate.
--
-- The repository now has a deterministic NotebookLM intake gate that
-- normalizes notebook list output, enriches source counts when metadata is
-- available, deduplicates against GitHub Issues/repo references, persists skip
-- reasons, and emits issue drafts for unapplied notebooks.

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = 'approved',
    remaining_work = 'Implemented scripts/notebooklm_intake_gate.py with normalized snapshot/report/state/issue-draft outputs, GitHub Issue deduplication, persistent skip reasons, and harness notebook priority routing.',
    recovery_plan = 'Session start now has a deterministic NotebookLM intake command in AGENTS.md. Follow-up notebooks should be routed through docs/notebooklm-intake/issue-drafts.md and existing Issues before new Issue creation.',
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Codex #3 / 2026-05-03] Added NotebookLM intake diff gate outputs under docs/notebooklm-intake and connected the command to AGENTS.md session start.'
WHERE github_issue_number = 1606
   OR title ILIKE '%NotebookLM list%差分ゲート%'
   OR title ILIKE '%NotebookLM list%Issue/WBS%';

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'Codex #3: NotebookLM intake diff gate',
  'Added a dependency-free NotebookLM intake gate that normalizes list/metadata output, routes notebooks to existing GitHub Issues/WBS/docs or skip reasons, and produces issue drafts for unapplied sources.',
  '2026-05-03'
)
ON CONFLICT DO NOTHING;
