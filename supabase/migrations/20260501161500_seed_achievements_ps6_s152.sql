-- PS#6 S152: prev3FormTrendBonus — 3走着順改善トレンド補正 confidence 68 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S152: 競馬予測EF confidence 68 terms — prev3FormTrendBonus追加',
  '前3走着順トレンド補正(prev3FormTrendBonus)を追加。prev_finish<prev2_finish<prev3_finish(着順が連続改善)=+1%(上昇気流シグナル)。逆に連続悪化(f1>f2>f3)=-1%(下降トレンド)。2走一貫(prev2Consist/S145)が直近2走の一致を見るのに対し、本補正は3走にわたる方向性(トレンド)を評価。confidence formula 68 terms体制確立。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
