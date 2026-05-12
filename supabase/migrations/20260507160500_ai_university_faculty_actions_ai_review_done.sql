-- Finalize the WBS row after PR #2145 merged/deployed. The WBS AI-review
-- trigger keeps progress=100 rows in_progress unless review state is explicit.

UPDATE public.wbs_tasks
SET
  status = 'completed',
  progress = 100,
  ai_review_status = 'manual_override',
  ai_review_notes = 'PR #2145 merged and production deploy 25506238443 succeeded. Codex #1 verified all four ai-hub AI University actions with production smoke.',
  ai_reviewed_at = now(),
  updated_at = now()
WHERE title = 'AI University faculty and department actions in ai-hub';
