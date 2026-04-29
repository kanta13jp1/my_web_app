-- PS#6 S113: horseWeightStabilityBonus — 馬体重安定性confidenceボーナス (29 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S113: 競馬予想モデル horseWeightStabilityBonus (馬体重安定性confidenceボーナス)',
  'horseWeightStabilityBonus(topEntry)関数を追加。horse_weight_changeフィールドを使用。±2kg以内=+0.01(体重安定管理/予測容易)/±8kg以上=-0.01(大幅変動/調整乱れ/予測困難)/3〜7kg=0(標準)。前走からの体重変動量でconfidenceを微調整。confidence式に組み込み29 terms体制確立。reasoning文字列に「体重安定:±X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
