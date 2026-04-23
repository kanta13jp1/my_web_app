-- WBS Codex completion: representative lane launcher for life-capital strategy.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: turn representative
-- life-capital lanes from analysis-only UI into executable launchers that open
-- the canonical feature directly from the all-feature AI strategy monitor.

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
  5,
  '全機能生命資本別 代表導線ランチャー',
  '生命資本別の代表導線レーンから、その場で代表機能を直接開き、束ねたサブ導線も一覧できるランチャーを追加する。AI分析/KGI/CSF/KPIの結果を、時間・お金・健康・体力・知能・集中力の浪費削減アクションへ即接続する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added representative-lane launch buttons plus a bundled sub-feature sheet to the all-feature AI strategy monitor, and wired HomePage so lane launches open the canonical feature while updating usage tracking.',
  'Next: extend the representative launcher pattern to non-Home entry points and add richer alias labels so bundled features can be retired without confusing navigation.',
  0.8
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本別 代表導線ランチャー'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本別 代表導線ランチャー',
  'Codex turned representative life-capital lanes into executable launchers so users can open the canonical feature directly from the all-feature AI strategy monitor and inspect bundled sub-features without leaving the decision context.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
