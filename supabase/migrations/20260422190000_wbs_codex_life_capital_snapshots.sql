-- WBS Codex takeover: life-capital daily snapshots and degradation alerts.
-- 2026-04-22
--
-- Scoped to the actual Codex work in this session: persist daily local
-- life-capital snapshots for time, money, health, stamina, intelligence, and
-- focus, then alert when any resource stays below 80% across multiple days.

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
  'コアSaaS機能',
  '💼',
  4,
  'ライフ資本日次スナップショット + 継続低下アラート',
  '時間・お金・健康・体力・知能・集中力のライフ資本スコアを日次で端末内に保存し、2日以上80%未満が続く資本をアラート化して次アクションへ接続する。',
  'vscode',
  'codex',
  'completed',
  100,
  '2026-04-22',
  '2026-04-22',
  'beta',
  'high',
  'Done 2026-04-22: Codex persisted 30 days of local life-capital snapshots, added repeated-below-80 alerts, surfaced the monitoring summary in the home command center, and covered the service with tests.',
  'Next: move snapshots to Supabase after authenticated multi-device sync and notification routing are required.',
  2
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = 'ライフ資本日次スナップショット + 継続低下アラート'
);

UPDATE wbs_tasks
SET
  remaining_work = 'Done 2026-04-22: Codex followed up the command center by adding daily life-capital snapshots and repeated-degradation alerts.',
  recovery_plan = 'Next: move snapshots to Supabase after authenticated multi-device sync and notification routing are required.'
WHERE title = 'ライフ浪費ゼロ司令塔 + AI抽象化';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'ライフ資本日次スナップショット + 継続低下アラート',
  'Codex added daily local monitoring for the life waste-zero command center. The app now saves 30 days of life-capital snapshots, detects when time, money, health, stamina, intelligence, or focus stays below 80% for multiple days, and shows alerts plus next actions on the home page.',
  '2026-04-22'
)
ON CONFLICT DO NOTHING;
