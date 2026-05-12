-- PS#5 S90: collision patrol — 009000 ps6_s102→009100
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S90: migration timestamp collision patrol (1件解消)',
  '20260429009000 の衝突 (seed_achievements_ps4_s106 vs seed_achievements_ps6_s102) を検出。'
  'seed_achievements_ps6_s102 を 009100 へ rename 解消。'
  '917 timestamps 全 unique 確認 (check_migration_timestamps.py: OK)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
