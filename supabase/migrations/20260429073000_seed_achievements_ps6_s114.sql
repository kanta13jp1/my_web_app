-- PS#6 S114: ageOptimalBonus — 年齢ピーク期confidenceボーナス (30 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S114: 競馬予想モデル ageOptimalBonus (年齢ピーク期confidenceボーナス)',
  'ageOptimalBonus(topEntry)関数を追加。age_sexフィールドから年齢を抽出。4歳=+0.02(ピーク/予測容易)/5歳=+0.01(安定)/6歳以上=-0.01(下降期/不確実)/3歳以下=0(成長途上)。競馬の年齢別パフォーマンス特性をconfidenceに反映。confidence式に組み込み30 terms体制確立。reasoning文字列に「年齢補正:±X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
