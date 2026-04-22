-- WBS Codex takeover: feature-wide AI strategy review integration.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: connect the completed
-- feature strategy monitor to ai-hub provider.chat, show an AI portfolio
-- review, and keep a local KPI-engine fallback for quota or provider failures.

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
  5,
  '全機能AI戦略レビュー実AI連携',
  '全機能AI戦略モニタリング結果を ai-hub provider.chat に渡し、現状分析、重要CSF、CSFに基づくKPI改善アクションをAIレビューとして返す。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added FeatureStrategyAiReviewService, wired home monitoring to ai-hub provider.chat, displayed the AI strategy review, and added fallback/test coverage.',
  'Completed in this slice. Next: persist AI review history for trend analysis and expose weekly digest notifications if product usage warrants it.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能AI戦略レビュー実AI連携'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能AI戦略レビュー実AI連携',
  'Codex が全機能AI戦略モニタリング結果を ai-hub provider.chat に接続し、現状分析、重要CSF、次回改善アクションをAIレビューとしてホームに表示。AI失敗時はローカルKPI分析にフォールバックするようにした。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
