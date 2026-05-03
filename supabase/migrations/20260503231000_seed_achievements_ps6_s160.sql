-- PS#6 S160: consecutiveTopThreeBonus — 前3走連続3着以内補正 confidence 76 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S160: 競馬予測EF confidence 76 terms — consecutiveTopThreeBonus追加',
  '前3走連続3着以内補正(consecutiveTopThreeBonus)を追加。①prev_finish/prev2_finish/prev3_finish全て3以下=+1%(前3走全て馬券圏内=圧倒的な安定した馬券貢献力)。②全て4以上=-1%(前3走一貫して馬券圏外=底力不足シグナル)。prev2FinishConsistencyBonus(S147:前2走両方3着以内)が2走チェックするのに対し、本補正は3走全てを対象とした拡張版安定性評価。prev3AvgFinish(S156:平均着順≤2.0)と補完関係。confidence formula 76 terms体制確立。',
  '2026-05-03'
) ON CONFLICT DO NOTHING;
