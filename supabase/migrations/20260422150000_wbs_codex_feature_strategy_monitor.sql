-- WBS Codex takeover: feature-wide AI strategy monitoring foundation.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: add a HomeToolCatalog-wide
-- AI analysis layer that creates KGI, CSF, KPI, monitoring status, and next
-- improvement actions for every exposed feature.

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
  '全機能AI戦略モニタリング基盤',
  'HomeToolCatalog 全機能を対象に、AI分析、KGI、KGI達成のためのCSF、CSFベースの数値KPI、定期モニタリング、改善アクションを自動生成する横断基盤を追加する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added FeatureStrategyMonitorService, a feature strategy report model, a home panel with KGI/CSF/KPI and accordion queues, and tests for the service/UI.',
  'Completed in this slice. Next: connect the generated monitor report to ai-hub for natural-language weekly summaries and persist historical snapshots if product analytics require trends.',
  4
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能AI戦略モニタリング基盤'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能AI戦略モニタリング基盤',
  'Codex が HomeToolCatalog 全機能を対象に、AI分析、KGI、CSF、数値KPI、定期モニタリング、改善キューを生成する共通基盤を追加。ホームに横断パネルを表示し、長い一覧はアコーディオンで畳めるようにした。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
