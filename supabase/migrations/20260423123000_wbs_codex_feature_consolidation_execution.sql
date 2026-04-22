-- WBS Codex takeover: all-feature consolidation execution loop.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: turn the existing
-- consolidation monitor into an executable abstraction plan, so similar
-- features are grouped under one canonical feature and measured as
-- time/focus waste reduction.

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
  '全機能類似導線の抽象化・統合実行KPI',
  '全機能AI戦略モニターの類似機能候補を、代表機能ID・対象機能ID・横断セクション・統合アクション・導線迷い削減見込み分として構造化し、KGI/CSF/KPI、AIレビュー、Home UIへ戻す。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex converted all-feature consolidation candidates into executable canonical-feature plans with estimated time/focus waste reduction, portfolio KPI, AI review prompt context, UI badges, and regression tests.',
  'Next: when a dedicated feature registry table exists, persist canonical_feature_id and merged_feature_ids so navigation can physically hide duplicate entries after review.',
  1.5
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能類似導線の抽象化・統合実行KPI'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能類似導線の抽象化・統合実行KPI',
  'Codex upgraded the all-feature AI strategy monitor so duplicate/similar features are grouped across sections under a canonical feature, measured as time/focus waste reduction, and included in KGI/CSF/KPI plus AI review context.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
