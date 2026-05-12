-- PS#6 S127: weightChangeBonus (体重変動補正) — confidence 43 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S127: 体重変動補正 (weightChangeBonus) confidence 43 terms',
  '競馬予測EF confidence式に体重変動補正(weightChangeBonus)を追加。微増(+2〜+6kg)=+1%(好調充実/仕上がり良好)/大変動(±8kg超)=-1%(体調不安定リスク)/小幅変動=0(標準)。weightChangeScore(ソート用)と差別化した信頼度専用の体重変動評価。43 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
