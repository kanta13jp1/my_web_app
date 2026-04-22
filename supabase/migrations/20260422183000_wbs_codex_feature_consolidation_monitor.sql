-- WBS Codex takeover: feature strategy consolidation monitor.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: keep the all-feature
-- AI/KGI/CSF/KPI monitor, add similar-feature consolidation candidates, and
-- repair garbled Japanese copy in the strategy and life-waste panels.

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
  '全機能AI戦略モニタリング 類似機能抽象化',
  '全機能のAI分析、KGI、CSF、KPI、定期モニタリング、改善アクションに加えて、類似機能を統合候補として自動抽出し、抽象化して一つの代表導線にまとめる判断材料を表示する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex added FeatureConsolidationCandidate, clustered similar HomeToolCatalog features by section and useful keyword axes, included consolidation candidates in the AI strategy review prompt, exposed them in the monitor UI, and repaired garbled Japanese copy in the related panels.',
  'Completed in this slice. Next: persist consolidation decisions and optionally hide deprecated duplicate routes after user approval.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能AI戦略モニタリング 類似機能抽象化'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能AI戦略モニタリング 類似機能抽象化',
  'Codex extended the all-feature AI strategy monitor with similar-feature consolidation candidates, added KGI/CSF/KPI plans for each consolidation candidate, included those candidates in the ai-hub provider.chat review prompt, and fixed garbled Japanese copy in the strategy, life-waste, and asset waste-training AI surfaces.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
