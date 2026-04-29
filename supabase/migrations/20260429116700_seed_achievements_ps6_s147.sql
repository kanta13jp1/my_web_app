-- PS#6 S147: prev2FinishConsistencyBonus — 2走一貫性ボーナス confidence 63 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S147: 競馬予測EF confidence 63 terms — prev2FinishConsistencyBonus追加',
  '直近2走連続3着以内=+2%/直近2走連続7着以下=-1%のボーナスを追加。近走の安定感(上昇モメンタム/不振継続)を信頼度に反映するシグナル。confidence formula 63 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
