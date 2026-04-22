-- WBS Codex takeover: local election snapshot note button.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: expose the existing Kokumin
-- local legislator aggregation note publisher from the election dashboard UI.

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
  '統一地方選 地方議員集計ノート化導線',
  '国民民主党地方議員集計の既存ノート生成機能を統一地方選700必達管理室のボタンから直接実行できるようにし、全県連KPIノートとは別のリンクコピー導線を用意する',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex added the local legislator aggregation note button, snapshot note link copy, and separate KPI note link label.',
  'Completed in this slice. Next risk: if multiple public note types keep growing, consolidate note actions into a compact menu.',
  1
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 地方議員集計ノート化導線'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 地方議員集計ノート化導線',
  'Codex が統一地方選700必達管理室のアクション列を改善。国民民主党地方議員集計の既存ノート生成を直接呼び出すボタンとリンクコピー導線を追加し、全県連KPIノートのリンクコピーと区別した。',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
