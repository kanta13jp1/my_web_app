-- PS#6 S161: popularityShiftBonus — 人気急変補正 confidence 77 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S161: 競馬予測EF confidence 77 terms — popularityShiftBonus追加',
  '人気急変補正(popularityShiftBonus)を追加。current popularityとprev_popularityの差(prev-curr)を算出。①差+3以上=+1%(市場が3ランク以上急速評価上昇=陣営強化/状態急上昇の市場認知)。②差-3以下=-1%(市場が3ランク以上急速評価下落=状態悪化/配当妙味なし)。favoriteConsistencyBonus(S149:1番人気に限定)が特定人気での一貫性を見るのに対し、本補正は全人気帯での相対的変化量を評価。confidence formula 77 terms体制確立。',
  '2026-05-03'
) ON CONFLICT DO NOTHING;
