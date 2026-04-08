-- Session PS#27: CI/CD全10ワークフロー品質強化 (PowerShell全体管理)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'CI/CD全10ワークフロー品質強化',
  'flutter analyze/deno lint強制ゲート化、全ワークフローにconcurrency・timeout・schedule_task_runs・GITHUB_STEP_SUMMARY追加。dependency-audit.yml・dependabot.yml新規作成。EF未分類検出CIステップ追加。',
  '2026-04-08'
)
ON CONFLICT DO NOTHING;
