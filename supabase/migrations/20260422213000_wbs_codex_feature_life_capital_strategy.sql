-- WBS Codex takeover: feature-wide life-capital strategy monitor.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: extend the existing
-- all-feature AI/KGI/CSF/KPI monitor with the life-management priority of
-- reducing waste in time, money, health, stamina, intelligence, and focus.

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
  '全機能生命資本KGI/CSF/KPIモニター',
  '全機能AI戦略モニタリングに、時間・お金・健康・体力・知能・集中力の浪費削減軸を追加する。各機能を守る生命資本へ分類し、KGI/CSF/KPI、浪費削減スコア、定期モニタリング頻度、改善対象を横断表示する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex extended the all-feature strategy monitor with life-capital classification, waste-reduction CSF/KPI metrics, AI review prompt context, UI summary tiles, and a foldable life-capital accordion.',
  'Next: tune the keyword-to-life-capital classifier with production usage logs if any feature is classified into the wrong resource.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本KGI/CSF/KPIモニター'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本KGI/CSF/KPIモニター',
  'Codex extended the existing all-feature AI strategy monitor so every feature is mapped to a life-capital resource, scored for waste reduction, included in AI review context, and rendered through summary tiles plus a foldable life-capital KGI/CSF/KPI accordion.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
