-- PS#6 S140: prevDistanceTrendBonus (前走距離増減傾向補正) — confidence 56 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S140: 前走距離増減傾向補正 (prevDistanceTrendBonus) confidence 56 terms',
  '競馬予測EF confidence式に前走距離増減傾向補正(prevDistanceTrendBonus)を追加。距離短縮(200m以上)=+1%(スピード優位/余力残る/距離ゆとりで安定)。大幅距離延長(500m以上)=-1%(スタミナ未知/距離適性リスク高)。prevDistanceMatchBonusが距離差の絶対値で評価するのに対し本補正は距離変化の方向性(短縮か延長か)を評価する。短縮馬は一般に好走率が高いという競馬定説を数値化。56 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
