-- PS#6 S64: GHA horse-racing-update workflow UX improvements
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S64 — 競馬GHAワークフロー UX改善',
    'horse-racing-update.yml: workflow_dispatch inputs.mode 説明に history/evaluate を追記 (8モード明示)。stats ステップを inputs.days を参照するように修正 (hardcoded 7 → ${{ inputs.days || ''7'' }})。argparse --days help text を backfill/stats 両方に言及するよう更新。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
