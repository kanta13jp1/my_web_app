-- Codex takeover: BYPASS_RULES secret setup support.
--
-- Codex verified that the repository secret exists and added a safe
-- verify/rotation script that avoids passing the PAT on the command line.
-- The remaining work is a workflow smoke test to confirm the token still has
-- the necessary bypass permission.

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
