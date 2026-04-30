-- WBS update: Top 10 expired task triage.
-- Win132 part 103 / 2026-04-30.
--
-- Keep WBS progress updates replay-safe:
-- - completed rows set ai_review_status away from pending so completion is stable
-- - in-progress overdue rows receive recovery_plan before the recovery trigger checks
-- - Codex #2 context is recorded in descriptions, while instance values remain canonical

-- 1. Win-owned direct work completed.
UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = CASE
      WHEN ai_review_status IN ('pending', 'requested') THEN 'skip'
      ELSE ai_review_status
    END,
    recovery_plan = COALESCE(NULLIF(trim(recovery_plan), ''), 'Completed in Win132 part 103 triage.'),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE github_issue_number = 1267;

UPDATE public.wbs_tasks
SET status = 'completed',
    progress = 100,
    ai_review_status = CASE
      WHEN ai_review_status IN ('pending', 'requested') THEN 'skip'
      ELSE ai_review_status
    END,
    recovery_plan = COALESCE(NULLIF(trim(recovery_plan), ''), 'Completed in Win132 part 103 triage.'),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE github_issue_number = 926;

-- 2. Handoff work moved to active planning.
UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = 10,
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Cross-instance handoff created in Win132 part 103; Codex #2 owns MCP_AUTH follow-up planning.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 103] Cross-instance handoff created in docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md. Codex #2 owns MCP_AUTH follow-up planning.'
WHERE github_issue_number IN (845, 846, 1268, 1036, 1037, 1123);

UPDATE public.wbs_tasks
SET status = 'in_progress',
    progress = 10,
    recovery_plan = COALESCE(
      NULLIF(trim(recovery_plan), ''),
      'Cross-instance handoff created in Win132 part 103; VSCode owns UI follow-up planning.'
    ),
    recovery_planned_at = COALESCE(recovery_planned_at, NOW()),
    description = COALESCE(description, '') ||
      E'\n\n[Win132 part 103] Cross-instance handoff created in docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md. VSCode owns UI follow-up planning.'
WHERE github_issue_number IN (1265, 1269, 1124);

-- 3. AI_FLEET_SYNERGY infrastructure follow-up tasks.
INSERT INTO public.wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[AI_FLEET_SYNERGY #1 extension] instance_conflict_predictor.py monthly cron',
  'CX',
  'codex',
  'codex',
  'medium',
  'pending',
  20,
  'Win132 part 103 implemented scripts/instance_conflict_predictor.py. Codex #2 owns monthly GitHub Actions automation alongside instance-role-audit.yml.'
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[AI_FLEET_SYNERGY #1 extension] instance_conflict_predictor.py monthly cron'
);

INSERT INTO public.wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[N-time alarm Phase 5] Top expired tasks batch handoff cross-instance-pr',
  'CX',
  'win',
  'win',
  'high',
  'completed',
  100,
  'Win132 part 103 completed docs/cross-instance-prs/20260430_top10_expired_tasks_batch_handoff.md and routed the top expired tasks across instances.'
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[N-time alarm Phase 5] Top expired tasks batch handoff cross-instance-pr'
);

-- 4. Production console errors: VSCode follow-up.
INSERT INTO public.wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[P0] production console errors investigation and fix',
  'CX',
  'vscode',
  'vscode',
  'high',
  'pending',
  0,
  'Win132 part 103 observed production console errors. VSCode owns release-mode reproduction, fix, and integration coverage.'
WHERE NOT EXISTS (
  SELECT 1 FROM public.wbs_tasks
  WHERE title = '[P0] production console errors investigation and fix'
);

-- 5. development_achievements record.
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win132 part 103: Top 10 expired task triage + N-time alarm Phase 5 dogfood',
  'Triaged the highest-priority expired WBS tasks, completed Win-owned direct work, handed Codex #2 and VSCode tasks to their owner tracks, and recorded the N-time alarm Phase 5 pattern.',
  '2026-04-30'
)
ON CONFLICT DO NOTHING;
