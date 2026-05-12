-- PS#6 S108: distanceSpecificBonus — レース距離別confidence調整 (24 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S108: 競馬予想モデル distanceSpecificBonus (距離別confidenceボーナス/ペナルティ)',
  'distanceSpecificBonus(distance)関数を追加。≤1200m=+0.02(スプリント/直線スピード主体/予測容易)/≤1600m=+0.01(マイル)/≥2400m=-0.02(長距離/スタミナ不確実)/≥2000m=-0.01/それ以外=0。confidence式に組み込み24 terms体制確立。reasoning文字列に「距離補正:±X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
