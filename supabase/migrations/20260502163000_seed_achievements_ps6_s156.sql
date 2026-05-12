-- PS#6 S156: prev3AvgFinishBonus — 前3走平均着順安定補正 confidence 72 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S156: 競馬予測EF confidence 72 terms — prev3AvgFinishBonus追加',
  '前3走平均着順安定補正(prev3AvgFinishBonus)を追加。prev_finish+prev2_finish+prev3_finishの平均を算出。①平均2.0以内=+1%(前3走で常に上位入線/圧倒的安定感)。②平均7.0以上=-1%(前3走で不安定な戦績/実力不足シグナル)。prev3FormTrendBonus(S152)が着順の方向性(上昇/下降トレンド)を見るのに対し、本補正は絶対水準(高水準安定/低水準不安定)を評価。confidence formula 72 terms体制確立。',
  '2026-05-02'
) ON CONFLICT DO NOTHING;
