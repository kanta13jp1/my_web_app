-- PS#5 S92: collision patrol — 015000 vscode_s15→015100
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S92: migration timestamp collision patrol (1件解消)',
  '20260429015000 の衝突 (seed_achievements_ps4_s110 vs seed_achievements_vscode_s15) を検出。'
  'seed_achievements_vscode_s15 を 015100 へ rename 解消。'
  '925 timestamps 全 unique 確認 (check_migration_timestamps.py: OK)。'
  'CI: success。EF gap: なし。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
