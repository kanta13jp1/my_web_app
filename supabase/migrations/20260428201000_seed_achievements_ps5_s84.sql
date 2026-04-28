-- PS#5 S84: collision patrol — 4 timestamp collisions resolved
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#5 S84: migration timestamp collision patrol (4件解消)',
  '20260428193000/196000x2/199000 の4衝突を検出・rename解消。'
  'seed_achievements_ps6_s90→193200 / seed_achievements_ps6_s91→196100 / '
  'seed_encord_ai_university→196200 / seed_appen_ai_university→199100。'
  '876 timestamps 全 unique 確認 (check_migration_timestamps.py: OK)。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
