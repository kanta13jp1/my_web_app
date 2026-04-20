-- WBS planned vs actual 列分離 + recovery_plan error block trigger
-- Win版#131 part 14 / T2-Win (2026-04-21)
--
-- 参照: docs/cross-instance-prs/20260420_wbs_gantt_overhaul_phase2.md (T2)
--
-- ユーザー決裁 (2026-04-20 夜 by PS#4 S30):
--   T2 = (A) error block — 遅延タスクで recovery_plan empty なら save 失敗。
--   defense-in-depth: DB trigger + EF validation 両方実装。
--
-- このマイグレーションで:
--   1. planned_start_date / planned_end_date 列追加 (計画値)
--   2. 既存 start_date / end_date を actual として維持 (実績値)
--   3. backfill: 既存全タスクで planned = actual コピー
--   4. wbs_delayed_tasks_view 書換: planned_end_date 優先 + end_date フォールバック
--   5. recovery_plan 必須 trigger: 遅延 (planned_end_date < today) かつ
--      status != 'completed' なら recovery_plan 非空必須

-- ============================================================
-- 1. planned_* 列追加
-- ============================================================
ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS planned_start_date date,
  ADD COLUMN IF NOT EXISTS planned_end_date   date;

COMMENT ON COLUMN wbs_tasks.planned_start_date IS '計画開始日 (ベースライン)。end_date=実績終了日と分離し、S-curve overlay で計画 vs 実績比較可能に';
COMMENT ON COLUMN wbs_tasks.planned_end_date   IS '計画終了日 (ベースライン)。遅延判定の primary。未設定時は end_date にフォールバック';

-- ============================================================
-- 2. 既存値 backfill (planned = actual 初期コピー)
-- ============================================================
UPDATE wbs_tasks
SET planned_start_date = start_date
WHERE planned_start_date IS NULL AND start_date IS NOT NULL;

UPDATE wbs_tasks
SET planned_end_date = end_date
WHERE planned_end_date IS NULL AND end_date IS NOT NULL;

-- ============================================================
-- 3. wbs_delayed_tasks_view 書換 (planned_end_date 優先)
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
  planned_start_date,
  planned_end_date,
  -- 遅延判定の基準日 = planned_end_date があれば優先 / なければ end_date
  COALESCE(planned_end_date, end_date) AS deadline_date,
  -- 遅延日数 (今日 - deadline / status != completed の場合)
  CASE
    WHEN status = 'completed' THEN 0
    WHEN COALESCE(planned_end_date, end_date) IS NULL THEN 0
    WHEN COALESCE(planned_end_date, end_date) < CURRENT_DATE
      THEN CURRENT_DATE - COALESCE(planned_end_date, end_date)
    ELSE 0
  END AS delay_days,
  -- リカバリープラン状況
  CASE
    WHEN status = 'completed' THEN 'on_track'
    WHEN COALESCE(planned_end_date, end_date) IS NULL THEN 'no_deadline'
    WHEN COALESCE(planned_end_date, end_date) >= CURRENT_DATE THEN 'on_track'
    WHEN recovery_plan IS NOT NULL AND length(trim(recovery_plan)) > 0
      THEN 'has_recovery_plan'
    ELSE 'delay_no_plan'
  END AS recovery_status,
  recovery_plan,
  recovery_planned_at,
  rescheduled_count,
  priority,
  milestone_code,
  updated_at
FROM wbs_tasks
WHERE COALESCE(planned_end_date, end_date) IS NOT NULL
  AND status != 'completed';

COMMENT ON VIEW wbs_delayed_tasks_view IS
  '遅延中タスク一覧 + リカバリー案有無。deadline_date = planned_end_date || end_date。delay_no_plan は要対処。T2-Win (part 14)';

-- ============================================================
-- 4. recovery_plan 未入力の既存遅延タスクを placeholder で backfill
-- ============================================================
-- trigger 有効化前に既存データを健全化 (空 recovery_plan の delayed タスクを解消)
UPDATE wbs_tasks
SET recovery_plan = 'TBD — 遅延 detect 済・リカバリー案未定 (T2-Win backfill)',
    recovery_planned_at = COALESCE(recovery_planned_at, NOW())
WHERE status != 'completed'
  AND COALESCE(planned_end_date, end_date) < CURRENT_DATE
  AND (recovery_plan IS NULL OR length(trim(recovery_plan)) = 0);

-- ============================================================
-- 5. recovery_plan 必須 trigger (T2 = (A) error block)
-- ============================================================
CREATE OR REPLACE FUNCTION wbs_enforce_recovery_plan()
RETURNS trigger
LANGUAGE plpgsql
AS $fn$
DECLARE
  v_deadline date;
BEGIN
  -- 完了済は常に通す
  IF NEW.status = 'completed' THEN
    RETURN NEW;
  END IF;

  -- deadline = planned_end_date 優先
  v_deadline := COALESCE(NEW.planned_end_date, NEW.end_date);

  -- deadline 未設定は通す (未確定タスク)
  IF v_deadline IS NULL THEN
    RETURN NEW;
  END IF;

  -- 遅延していなければ通す
  IF v_deadline >= CURRENT_DATE THEN
    RETURN NEW;
  END IF;

  -- 遅延 + recovery_plan 空 → error block
  IF NEW.recovery_plan IS NULL OR length(trim(NEW.recovery_plan)) = 0 THEN
    RAISE EXCEPTION
      '遅延タスク % (deadline=%) には recovery_plan が必須です。wbs.update_progress で recovery_plan パラメータを指定してください。',
      NEW.id, v_deadline
      USING HINT = 'recovery_plan 例: "Win版に並行で UI 着手", "scope 縮小: 5社→3社"',
            ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$fn$;

COMMENT ON FUNCTION wbs_enforce_recovery_plan() IS
  '遅延タスク (planned_end_date < today) の recovery_plan 必須化 trigger 関数 (T2-Win part 14)';

DROP TRIGGER IF EXISTS wbs_enforce_recovery_plan_trg ON wbs_tasks;
CREATE TRIGGER wbs_enforce_recovery_plan_trg
  BEFORE INSERT OR UPDATE ON wbs_tasks
  FOR EACH ROW
  EXECUTE FUNCTION wbs_enforce_recovery_plan();

-- ============================================================
-- 6. development_achievements 記録
-- ============================================================
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS part 14: planned vs actual 分離 + recovery_plan error block',
  $md$planned_start_date / planned_end_date 列追加で計画 vs 実績を分離。wbs_delayed_tasks_view を planned_end_date 優先に書換。recovery_plan 必須 trigger (wbs_enforce_recovery_plan) で遅延タスクの空 recovery_plan を DB level で block (defense-in-depth: EF validation も wbs.update_progress に追加予定)。Win版#131 part 14 / T2-Win。$md$,
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
