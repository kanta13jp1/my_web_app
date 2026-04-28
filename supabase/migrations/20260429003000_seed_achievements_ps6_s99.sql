-- PS#6 S99: 競馬予想モデル weightKgPenaltyScore — 斤量sort因子追加 (18因子体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S99: weightKgPenaltyScore — 斤量(weight_kg)をsort因子に追加 (18因子体制)',
  'sortHorseEntriesForLearningに17番目因子としてweightKgPenaltyScore(weight_kg)を追加。≤53kg=-1(軽斤量有利)/≤55kg=0(標準)/<57kg=+1(やや重い)/≥57kg=+2(重斤量不利)/データなし=0。horse_numberは18番目tiebreakに繰り上げ。sort 18因子体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
