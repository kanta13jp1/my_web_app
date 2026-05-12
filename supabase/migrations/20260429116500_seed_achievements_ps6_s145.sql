-- PS#6 S145: trackConditionAdaptBonus — 馬場適性ボーナス confidence 61 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S145: 競馬予測EF confidence 61 terms — trackConditionAdaptBonus追加',
  '前走道悪→今回道悪=+1%(道悪経験加点)/馬場転換(良→重/重→良)=-1%のボーナスを追加。馬場適性の継続性を信頼度に反映するシグナル。confidence formula 61 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
