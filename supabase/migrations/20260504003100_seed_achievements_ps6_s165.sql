-- PS#6 S165: formValueBonus — フォーム×人気バリュー補正 confidence 81 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S165: 競馬予測EF confidence 81 terms — formValueBonus追加',
  'フォーム×人気バリュー補正(formValueBonus)を追加。前走着順と現在人気の組み合わせで市場の過小/過大評価を検出。①前走2着以内かつ現在5番人気以下=+1%(好フォーム×低人気=市場見逃し価値馬/穴馬候補)。②前走8着以下かつ現在3番人気以上=-1%(不調×高人気=過大評価リスク/人気先行馬懸念)。popularityShiftBonus(S161:人気急変)が変化量を見るのに対し、本補正は現在フォームと人気の乖離構造を評価。confidence formula 81 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
