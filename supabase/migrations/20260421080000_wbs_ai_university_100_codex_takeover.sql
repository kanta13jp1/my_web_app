-- Codex takeover: AI University 100 providers.
--
-- Only the task Codex actually started is moved to the Codex owner.
-- This slice adds Cursor / Lovable / Bolt.new provider content.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 12),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex added Cursor / Lovable / Bolt.new AI University provider content with overview, use_cases, and quiz categories.',
    'Next: continue provider additions toward the next public milestone, add richer quizzes for new providers, and audit provider count from ai_university_content.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'If provider count drifts from WBS, use ai_university_content distinct provider count as source of truth and add idempotent seed migrations only.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title IN ('AI大学 100社達成', 'AI大学 100社+ コンテンツ完全化')
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI University 100 providers Codex takeover',
  'Codex が AI大学 100社達成を一時引き継ぎ、Cursor / Lovable / Bolt.new を追加して WBS を進行中に更新した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
