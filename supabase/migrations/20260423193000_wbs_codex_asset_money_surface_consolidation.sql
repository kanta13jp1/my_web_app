-- WBS Codex continuation: consolidate duplicate money surfaces into asset management.
-- 2026-04-23
--
-- Scoped to the actual Codex work in this session: continue the existing
-- MoneyForward-style asset management task by reducing duplicated money-entry
-- surfaces and routing day-to-day expense/budget flows into AssetManagementPage.

ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS owner_instance text NOT NULL DEFAULT 'vscode',
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS estimated_hours numeric DEFAULT 0;

UPDATE wbs_tasks
SET
  title = '資産管理 (MoneyForward対抗) (Codex引継ぎ)',
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 64),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done 2026-04-23: Codex consolidated the day-to-day money surfaces so 支出トラッカー and 家計・予算プランナー now open the canonical 資産管理 experience, while MoneyForward連携 and 予算・財務プランナー expose direct jumps into the same AI/KGI/KPI-enabled surface.'
  ),
  recovery_plan = concat_ws(
    E'\n',
    NULLIF(recovery_plan, ''),
    'Next: fold remaining advanced budget-planner and MoneyForward sync details into modular sections inside 資産管理 so the legacy pages can be retired completely without feature loss.'
  ),
  estimated_hours = GREATEST(COALESCE(estimated_hours, 0), 1.0),
  updated_at = now()
WHERE title IN (
  '資産管理 (MoneyForward対抗)',
  '資産管理 (MoneyForward対抗) (Codex引継ぎ)'
);

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '資産管理 金銭導線統合',
  'Codex routed the everyday money-entry surfaces into AssetManagementPage, added canonical-entry messaging, and exposed direct jumps from legacy MoneyForward and budget pages into the AI/KGI/KPI-driven asset management surface.',
  '2026-04-23'
)
ON CONFLICT DO NOTHING;
