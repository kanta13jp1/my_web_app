-- WBS Codex takeover: all-feature life-capital recovery roadmap.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: fix the order of today's
-- focus, the queued next focus, and later waiting capitals into one roadmap.

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
  '🧠',
  3,
  '全機能生命資本回復ロードマップ',
  '今日の1手、解放後の次候補、その後の待機資本までを6資本の順番で固定する回復ロードマップを全機能AI戦略モニターへ追加し、AIレビューとKGI/CSF/KPI、定期スナップショットの次アクションへ反映する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-23',
  '2026-04-23',
  'beta',
  'high',
  'Done 2026-04-23: Codex added a life-capital recovery roadmap that orders now/next/later steps and reflects the same order into AI review context, KPI metrics, and monitoring snapshots.',
  'Next: promote roadmap stage changes into proactive reminders once notification throttling is in place.',
  1.0
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '全機能生命資本回復ロードマップ'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '全機能生命資本回復ロードマップ',
  'Codex added a life-capital recovery roadmap so the AI strategy monitor can keep the user on one current action, one queued next action, and an ordered set of later capitals without spreading effort too early.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
