-- PS#6 S143: horseNumberFieldRatioBonus — 馬番フィールド比率ボーナス confidence 59 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S143: 競馬予測EF confidence 59 terms — horseNumberFieldRatioBonus追加',
  '馬番/頭数比率≤0.2(内枠有利)=+1%/≥0.85(大外)=-1%のボーナスを追加。絶対枠番ではなく相対的内外ポジションで補正するシグナル。confidence formula 59 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
