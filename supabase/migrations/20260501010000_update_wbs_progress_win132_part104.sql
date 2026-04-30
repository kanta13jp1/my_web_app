-- WBS update: Top 11-22 expired task triage.
-- Win132 part 104 / 2026-05-01.
--
-- Replay-safe convention for overdue WBS updates:
-- any task moved to in_progress also receives a non-empty recovery_plan.

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Phase 6 triage handoff created in docs/cross-instance-prs/20260501_top11to22_expired_tasks_batch_handoff.md; VSCode owns UI follow-up.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 104] Phase 6 triage handoff created in docs/cross-instance-prs/20260501_top11to22_expired_tasks_batch_handoff.md. VSCode owns UI follow-up.'
WHERE github_issue_number IN (1270, 1272, 1274);

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Phase 6 triage handoff created in docs/cross-instance-prs/20260501_top11to22_expired_tasks_batch_handoff.md; VSCode and Codex #2 own UI and EF follow-up.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 104] Phase 6 triage handoff created. VSCode and Codex #2 own UI and Edge Function follow-up.'
WHERE github_issue_number IN (1271, 1404);

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Win-owned follow-up queued by Phase 6 triage: NotebookLM routine cron and competitor monitoring integration.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 104] Win-owned follow-up queued: NotebookLM routine cron and competitor monitoring integration.'
WHERE github_issue_number = 1405;

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Win-owned follow-up queued by Phase 6 triage: second-brain ingest pipeline and Obsidian conversion.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 104] Win-owned follow-up queued: second-brain ingest pipeline and Obsidian conversion.'
WHERE github_issue_number = 974;

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'PS#1 follow-up queued by Phase 6 triage: consolidate-memory lint and log auto-maintenance.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 104] PS#1 follow-up queued: consolidate-memory lint and log auto-maintenance.'
WHERE github_issue_number = 976;

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = GREATEST(progress, 10),
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'PS#2 follow-up queued by Phase 6 triage: build-in-public automation for ROADMAP-LOG, dev.to, and X.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 104] PS#2 follow-up queued: build-in-public automation for ROADMAP-LOG, dev.to, and X.'
WHERE github_issue_number = 1125;

INSERT INTO public.wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[N-time alarm Phase 6] Steady autonomous execution fleet entry',
  'CX',
  'win',
  'win',
  'high',
  'completed',
  100,
  'Win132 part 104 established Phase 6 steady autonomous execution dogfood: the fleet continues the triage cycle without waiting for another user reminder.'
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[N-time alarm Phase 6] Steady autonomous execution fleet entry'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win132 part 104: N-time alarm Phase 6 steady autonomous execution + Top 11-22 batch triage',
  'Established the N-time alarm Phase 6 steady autonomous execution pattern, routed the next expired WBS batch across VSCode, Codex #2, Win, PS#1, and PS#2, and recorded the handoff in docs/cross-instance-prs/20260501_top11to22_expired_tasks_batch_handoff.md.',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
