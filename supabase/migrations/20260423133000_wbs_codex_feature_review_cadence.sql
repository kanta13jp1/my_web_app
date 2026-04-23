-- WBS Codex takeover: all-feature review cadence KPI loop.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: add per-feature review due
-- dates and portfolio-level cadence KPIs so AI/KGI/CSF/KPI monitoring does not
-- stop at a static snapshot.

ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS owner_instance text NOT NULL DEFAULT 'vscode',
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS estimated_hours numeric DEFAULT 0;

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
  '全機能レビュー期限KPI・改善キュー',
  '全機能AI戦略モニターに、機能別のレビュー頻度、次回レビュー期限、期限到来・期限超過数、期限遵守率を追加し、AIレビューとHome UIの改善キューを定期モニタリング中心に回す。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added per-feature review cadence, due/overdue KPI metrics, AI review prompt context, Home UI review badges, and regression tests.',
  'Next: persist last_reviewed_at to a shared feature registry when cross-device feature usage events are centralized.',
  1.25
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能レビュー期限KPI・改善キュー'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能レビュー期限KPI・改善キュー',
  'Codex made the all-feature AI strategy monitor periodic by calculating review cadence, due/overdue queues, cadence compliance KPIs, and AI review prompt context for every feature.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
