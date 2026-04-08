-- Session PowerShell#9 (2026-04-08): CI/CD deno lint強制ゲート追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'CI deno lint強制ゲート追加 (PowerShell#9)',
    'ci.yml に denoland/setup-deno@v2 + deno lint --config supabase/functions/deno.json を追加。プロジェクトルール「deno lint 常に0エラー」をCIで強制化 (continue-on-error なし)。',
    '2026-04-08'
  ),
  (
    'GitHub Actions全ワークフロー品質ゲート整備完了',
    'flutter analyze (PS#6で追加) + deno lint (PS#9で追加) の両方をCIゲートとして強制。schedule_task_runs記録もcs-check/edge-function-audit/infra-health-checkに追加済みで監視体制完成。',
    '2026-04-08'
  )
ON CONFLICT DO NOTHING;
