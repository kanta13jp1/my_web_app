-- Codex takeover: Playwright E2E smoke test foundation.
--
-- Only the task Codex actually started is moved to the Codex owner.
-- This slice adds npm/Playwright config, production public-route smoke tests,
-- and a manual/scheduled GitHub Actions workflow.

UPDATE wbs_tasks
SET
  owner_instance = 'codex',
  status = CASE WHEN status = 'completed' THEN status ELSE 'in_progress' END,
  progress = GREATEST(progress, 20),
  remaining_work = concat_ws(
    E'\n',
    NULLIF(remaining_work, ''),
    'Done: Codex added package.json, Playwright config, public route smoke tests for /, /project-gantt, /referral, and a manual/scheduled e2e-smoke workflow.',
    'Next: add authenticated user journeys, visual regression snapshots, and deploy-prod post-deploy smoke gating once test accounts/secrets are available.'
  ),
  recovery_plan = CASE
    WHEN COALESCE(recovery_plan, '') = '' THEN
      'If E2E becomes flaky, keep public smoke tests as non-blocking scheduled checks and split authenticated flows behind dedicated test-user secrets.'
    ELSE recovery_plan
  END,
  updated_at = now()
WHERE title = 'E2Eテスト整備 (Playwright)'
  AND status <> 'completed';

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Playwright E2E smoke test foundation',
  'Codex が E2Eテスト整備 (Playwright) を一時引き継ぎ、npm/Playwright 設定、公開ルート smoke test、手動/週次 GitHub Actions workflow を追加。WBS owner を Codex に変更し、残作業を認証済み導線・画像回帰・post-deploy gate に整理した。',
  '2026-04-21'
)
ON CONFLICT DO NOTHING;
