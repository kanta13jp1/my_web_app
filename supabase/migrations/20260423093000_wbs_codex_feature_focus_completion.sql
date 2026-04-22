-- WBS Codex takeover: all-feature focus action completion loop.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: make the selected
-- low-hurdle life-capital action recordable as completed or deferred.

INSERT INTO wbs_tasks (
  category,
  category_icon,
  category_order,
  title,
  description,
  instance,
  owner_instance,
  status,
  progress,
  start_date,
  end_date,
  milestone_code,
  priority,
  remaining_work,
  recovery_plan,
  estimated_hours
)
SELECT
  'AI統合',
  '🤖',
  3,
  '全機能生命資本フォーカス完了ループ',
  '全機能AI戦略モニターで選定した今日の低ハードル1手を、完了または今日は観察として記録し、継続日数を見ながら広げすぎない改善サイクルに接続する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added local completion/defer state, streak tracking, UI action controls, and tests for the all-feature life-capital focus card.',
  'Next: sync completion outcomes to Supabase snapshots once a user-level analytics table is finalized.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本フォーカス完了ループ'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本フォーカス完了ループ',
  'Codex made the all-feature AI strategy monitor actionable by letting users close the selected low-hurdle life-capital action as completed or observation-only, with local streak tracking and regression tests.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
