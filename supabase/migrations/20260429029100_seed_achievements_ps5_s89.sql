-- PS#5 S89: collision patrol — 026000 lmstudio→026100
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S89: migration timestamp collision patrol (1件解消)',
  '20260429026000 の衝突 (seed_achievements_ps5_s88 vs seed_lmstudio_ai_university) を検出。'
  'seed_lmstudio_ai_university を 026100 へ rename 解消。'
  '915 timestamps 全 unique 確認 (check_migration_timestamps.py: OK)。'
  'CI/deploy: all green。EF gap: なし。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
