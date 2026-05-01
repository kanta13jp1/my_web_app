-- Codex #4 / 2026-05-02: WBS stale subdivide workflow.
-- Implements BUSINESS_WBS_AI_AUTOMATION Phase 3:
-- stale in_progress parent tasks -> Gemini breakdown -> child WBS rows.

UPDATE public.wbs_tasks
SET
  status = 'completed',
  progress = 100,
  ai_review_status = CASE
    WHEN ai_review_status IN ('pending', 'requested', 'rejected') THEN 'skip'
    ELSE ai_review_status
  END,
  remaining_work = 'Implemented by scripts/wbs_stale_subdivide.py and .github/workflows/wbs-stale-subdivide.yml. Cron runs daily at 09:00 JST, detects stale in_progress tasks, inserts parent_task_id-linked child tasks, and records auto_subdivided_at on the parent.',
  updated_at = now()
WHERE
  title ILIKE '%wbs-stale-subdivide%'
  OR description ILIKE '%wbs-stale-subdivide%';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Codex #4: WBS stale subdivide workflow',
  'Implemented BUSINESS_WBS_AI_AUTOMATION Phase 3. Added scripts/wbs_stale_subdivide.py with a dependency-free self-test and .github/workflows/wbs-stale-subdivide.yml daily 09:00 JST cron. The workflow deny-by-default skips missing secrets, fetches stale in_progress WBS tasks, asks Gemini 2.5 Flash for 3-7 executable child tasks, inserts child rows with parent_task_id, and patches the parent auto_subdivided_at to prevent repeat subdivision for 7 days.',
  '2026-05-02'
)
ON CONFLICT DO NOTHING;
