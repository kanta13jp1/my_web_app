-- WBS update — #976 + #1173 actual 実装完了 (Win版#132 part 105 / 2026-05-01)
--
-- Phase 6 自律実行 — 上から順 Win territory task を実装.

-- ==============================================
-- 1. #976 + #1173 完了 (= scripts/knowledge_vault_lint.py 実装)
-- ==============================================

UPDATE wbs_tasks
SET status = 'completed',
    progress = 100,
    description = COALESCE(description, '') || E'\n\n[Win版#132 part 105] scripts/knowledge_vault_lint.py 実装完了 (~250 行 / orphan 検出 + broken link + duplicate title + missing index entries / Health Score 算出 / docs/knowledge-vault-lint/<YYYY-MM-DD>.md 出力). .github/workflows/knowledge-vault-lint.yml 週次 cron 化. 初回実行: memory 1054 + docs 1652 = 2706 file 解析 / Health 0/100 / 2621 orphan + 21 broken + 29 dup + 896 missing index 検出 = actionable backlog.'
WHERE github_issue_number IN (976, 1173);

-- ==============================================
-- 2. AI_FLEET_SYNERGY 自進化 infra として記録
-- ==============================================

INSERT INTO wbs_tasks (title, category, instance, owner_instance, priority, status, progress, description)
SELECT
  '[SECOND_BRAIN #4 dogfood] knowledge_vault_lint.py + weekly cron',
  'CX',
  'win',
  'win',
  'medium',
  'completed',
  100,
  'Win版#132 part 105 で実装. Issues #976 + #1173 解決. memory/ + docs/ の Markdown 健康診断 (orphan / broken link / dup title / missing index entries). Health Score 算出. weekly cron (= .github/workflows/knowledge-vault-lint.yml / 月曜 02:00 UTC). 初回実行: 2706 file / Health 0/100 = 大量 cleanup backlog 識別.'
WHERE NOT EXISTS (
  SELECT 1 FROM wbs_tasks
  WHERE title = '[SECOND_BRAIN #4 dogfood] knowledge_vault_lint.py + weekly cron'
);

-- ==============================================
-- 3. development_achievements
-- ==============================================

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Win版#132 part 105: Knowledge Vault Lint 実装 (Issues #976 + #1173)',
  'Phase 6 自律実行 / 上から順 Win territory task 実装. scripts/knowledge_vault_lint.py 新規 (~250 行 / SECOND_BRAIN #4 + INDIE #1 dogfood). 週次 GHA cron knowledge-vault-lint.yml. 初回実行: memory/ 1054 + docs/ 1652 = 2706 file 解析 / Health Score 0/100 / 2621 orphan + 21 broken link + 29 duplicate title + 896 missing index = 大量 actionable cleanup backlog 自動識別.',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
