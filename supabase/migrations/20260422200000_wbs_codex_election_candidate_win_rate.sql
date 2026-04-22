-- WBS Codex takeover: candidate target and win-rate KPI calibration.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: set newcomer candidate
-- nomination targets to 1.25x the newcomer win target, assuming an 80% win
-- rate, and surface current win-rate KPIs during local-election batch updates.

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
  '統一地方選 擁立目標/当選率KPI調整',
  '当選率80%を前提に、新人擁立目標を新人当選目標の1.25倍へ統一し、バッチKPI更新時に現状当選率を計算・表示する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'alpha',
  'high',
  'Done 2026-04-22: Codex normalized candidate nomination targets to ceil(newcomer win target x 1.25), added current win-rate KPI storage, surfaced win-rate labels in map/detail/share outputs, and covered the behavior with tests.',
  'Next: tune the win-rate numerator after official result feeds distinguish newly elected challengers from incumbent roster changes.',
  1
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '統一地方選 擁立目標/当選率KPI調整'
);

UPDATE wbs_tasks
SET
  remaining_work = 'Done 2026-04-22: Codex applied the 80% assumed win-rate rule to candidate nomination targets and added current win-rate KPI display.',
  recovery_plan = 'Next: validate against official result feeds when challenger election outcomes become available.'
WHERE title = '統一地方選 県連別現実目標再調整';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '統一地方選 擁立目標/当選率KPI調整',
  'Codex changed local-election candidate target generation so newcomer nomination targets are ceil(newcomer win targets x 1.25), reflecting an assumed 80% win rate. Batch KPI updates now store current win-rate percentages and show them in the map detail, KGI/CSF/KPI rows, dashboard notes, and shared public-note metadata.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
