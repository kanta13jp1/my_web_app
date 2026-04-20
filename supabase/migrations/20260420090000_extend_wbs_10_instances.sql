-- WBS 10 インスタンス拡張 + recovery_plan 列追加 + CHECK constraint
-- Win版#131 part 10 (2026-04-20)
--
-- ユーザー報告: project-gantt UI で担当に PS#1-#6 / WEB / 📱 が含まれない。
-- 遅延タスクのリカバリー案列が無い。イナズマ線 (lightning line) 未実装。
--
-- このマイグレーションで:
--   1. instance 値を 11 種類に正式化 (vscode/win/ps1-6/web/mobile/all)
--   2. 既存値の backfill (windows → win, ps → ps1)
--   3. recovery_plan / delay_days_threshold 列追加
--   4. CHECK constraint で誤入力防止

-- ============================================================
-- 1. 既存値 backfill
-- ============================================================
UPDATE wbs_tasks SET instance = 'win'  WHERE instance = 'windows';
UPDATE wbs_tasks SET instance = 'ps1'  WHERE instance = 'ps';

-- ============================================================
-- 2. CHECK constraint 追加 (10 instance + all)
-- ============================================================
ALTER TABLE wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_instance_check;
ALTER TABLE wbs_tasks ADD CONSTRAINT wbs_tasks_instance_check
  CHECK (instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'all'
  ));

-- ============================================================
-- 3. recovery_plan 列追加 (遅延時のリカバリー案を必須化)
-- ============================================================
ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_planned_at timestamptz,
  ADD COLUMN IF NOT EXISTS rescheduled_count int NOT NULL DEFAULT 0;

COMMENT ON COLUMN wbs_tasks.recovery_plan IS '遅延発生時のリカバリー案 (例: "Win版に並行で UI 着手", "scope 縮小: 5社→3社"). 遅延タスクは必須記入';
COMMENT ON COLUMN wbs_tasks.recovery_planned_at IS 'recovery_plan が最後に更新された時刻';
COMMENT ON COLUMN wbs_tasks.rescheduled_count IS 'リスケされた回数 (3 回以上 = 根本的に scope 見直し対象)';

-- ============================================================
-- 4. View: 遅延タスク + リカバリー状況
-- ============================================================
CREATE OR REPLACE VIEW wbs_delayed_tasks_view AS
SELECT
  id,
  category,
  category_icon,
  title,
  instance,
  status,
  progress,
  start_date,
  end_date,
  -- 遅延日数 (今日 - end_date / status != completed の場合)
  CASE
    WHEN status = 'completed' THEN 0
    WHEN end_date IS NULL THEN 0
    WHEN end_date < CURRENT_DATE THEN CURRENT_DATE - end_date
    ELSE 0
  END AS delay_days,
  -- リカバリープラン状況
  CASE
    WHEN status = 'completed' THEN 'on_track'
    WHEN end_date IS NULL THEN 'no_deadline'
    WHEN end_date >= CURRENT_DATE THEN 'on_track'
    WHEN recovery_plan IS NOT NULL AND length(trim(recovery_plan)) > 0 THEN 'has_recovery_plan'
    ELSE 'delay_no_plan'  -- ← 警告対象
  END AS recovery_status,
  recovery_plan,
  recovery_planned_at,
  rescheduled_count,
  priority,
  milestone_code,
  updated_at
FROM wbs_tasks
WHERE end_date IS NOT NULL AND status != 'completed';

COMMENT ON VIEW wbs_delayed_tasks_view IS '遅延中タスク一覧 + リカバリー案有無。delay_no_plan は要対処';

-- ============================================================
-- 5. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS 10 インスタンス拡張 + リカバリー案列 + 遅延 view',
  'wbs_tasks.instance を 11 種類 (vscode/win/ps1-6/web/mobile/all) に正式化。recovery_plan 列追加で遅延時のリカバリー案を必須化。wbs_delayed_tasks_view で遅延タスク一覧 + recovery_status (on_track / has_recovery_plan / delay_no_plan) を集計。Win版#131 part 10。',
  '2026-04-20'
)
ON CONFLICT DO NOTHING;
