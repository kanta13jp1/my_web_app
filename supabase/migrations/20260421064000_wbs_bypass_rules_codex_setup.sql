-- Codex takeover: BYPASS_RULES secret setup support.
--
-- Codex verified that the repository secret exists and added a safe
-- verify/rotation script that avoids passing the PAT on the command line.
-- The remaining work is a workflow smoke test to confirm the token still has
-- the necessary bypass permission.

-- Some remote migration histories marked the WBS extension migrations as
-- applied without actually running their DDL. Keep this first pending Codex
-- WBS migration self-healing so later progress updates can use these columns
-- and the Codex owner value.
ALTER TABLE wbs_tasks
  ADD COLUMN IF NOT EXISTS estimated_hours numeric(6,1) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS owner_instance text,
  ADD COLUMN IF NOT EXISTS recovery_plan text DEFAULT '',
  ADD COLUMN IF NOT EXISTS recovery_planned_at timestamptz,
  ADD COLUMN IF NOT EXISTS rescheduled_count int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS remaining_work text DEFAULT '',
  ADD COLUMN IF NOT EXISTS depends_on uuid[] DEFAULT '{}'::uuid[],
  ADD COLUMN IF NOT EXISTS depends_on_titles text[] DEFAULT '{}'::text[],
  ADD COLUMN IF NOT EXISTS auto_recovery_applied boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS planned_start_date date,
  ADD COLUMN IF NOT EXISTS planned_end_date date;

UPDATE wbs_tasks
SET owner_instance = CASE
  WHEN instance = 'windows' THEN 'win'
  WHEN instance = 'ps' THEN 'ps1'
  WHEN instance = 'all' THEN 'vscode'
  WHEN instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha'
  ) THEN instance
  ELSE 'vscode'
END
WHERE owner_instance IS NULL
   OR owner_instance IN ('windows', 'ps', 'all');

ALTER TABLE wbs_tasks DROP CONSTRAINT IF EXISTS wbs_tasks_owner_instance_check;
ALTER TABLE wbs_tasks ADD CONSTRAINT wbs_tasks_owner_instance_check
  CHECK (owner_instance IN (
    'vscode', 'win',
    'ps1', 'ps2', 'ps3', 'ps4', 'ps5', 'ps6',
    'web', 'mobile',
    'schedule', 'gha',
    'codex'
  )) NOT VALID;

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 70),
  remaining_work =
    'BYPASS_RULES secret exists. Safe verify/rotation script and setup doc added. Remaining: run a workflow smoke test and rotate PAT only if GH006 persists.',
  recovery_plan =
    CASE
      WHEN COALESCE(recovery_plan, '') = '' THEN
        'If GH006 persists, rotate BYPASS_RULES using scripts/set_bypass_rules_secret.ps1 with a PAT that can bypass branch protection.'
      ELSE recovery_plan
    END,
  updated_at = now()
WHERE title = 'BYPASS_RULES secret設定'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'BYPASS_RULES secret setup support',
  'Codex が BYPASS_RULES secret の存在を確認し、平文引数を使わない PowerShell verify/rotation script とセットアップ手順を整備。WBS owner を Codex に変更し、残作業を workflow smoke test に明確化した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
