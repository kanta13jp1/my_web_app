-- PS#6 S149: favoriteConsistencyBonus — 本命継続ボーナス confidence 65 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S149: 競馬予測EF confidence 65 terms — favoriteConsistencyBonus追加',
  '今回1番人気かつ前走も1番人気=+1%(安定した市場評価)/今回1番人気かつ前走5番人気以下=-1%(急激な評価変動で不安定)のボーナスを追加。confidence formula 65 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
