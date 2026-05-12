-- PS#6 S98: 競馬予想モデル popularitySortScore — 人気順をsort因子に追加 (17因子体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S98: popularitySortScore — 人気順をsort因子に追加 (17因子体制)',
  'sortHorseEntriesForLearningに16番目因子としてpopularitySortScore(popularity)を追加。1-3番人気=0/4-6番人気=2/7-9番人気=4/10番人気以下=6/データなし=5。horse_numberは17番目tiebreakに繰り上げ。sort 17因子体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
