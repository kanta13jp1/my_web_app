-- PS#5 S85: collision patrol — 20260428202000 dataloop → 202100
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S85: migration timestamp collision patrol (1件解消)',
  '20260428202000 の衝突 (seed_achievements_ps6_s93 vs seed_dataloop_ai_university) を検出。'
  'seed_dataloop_ai_university を 202100 へ rename 解消。882 timestamps 全 unique 確認。'
  'EF deploy gap チェック: 全 EF deploy-prod.yml に記載済 (gap なし)。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
