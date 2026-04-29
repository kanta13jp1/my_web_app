-- PS#6 S146: runningStyleDistanceBonus — 脚質×距離適合ボーナス confidence 62 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S146: 競馬予測EF confidence 62 terms — runningStyleDistanceBonus追加',
  '逃/先行脚質×短距離(≤1400m)=+1%/差し/追込脚質×長距離(≥2000m)=+1%/逃/先行脚質×超長距離(≥2400m)=-1%のボーナスを追加。脚質と距離の相性を信頼度に反映するシグナル。confidence formula 62 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
