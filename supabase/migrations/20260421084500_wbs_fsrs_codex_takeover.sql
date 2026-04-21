-- Codex takeover: FSRS learning system UI guardrails.
--
-- Only the FSRS task Codex actually started is moved to the Codex owner.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 92),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex fixed AiFsrsService Japanese grade labels, calendar-day next due labels, client-side grade normalization, and added regression tests for FSRS labels/payload parsing.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'Next: add an ai-hub quiz.fsrs_grade integration fixture and expose retention/stability metrics on the AI University dashboard.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'FSRS学習システム完全実装'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'FSRS learning system Codex takeover',
  'Codex took over the FSRS learning system task, fixed Japanese grade labels and calendar-day next due labels in AiFsrsService, normalized invalid grade values before the edge call, added FsrsCard payload parsing coverage, and updated WBS progress to 92%.',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
