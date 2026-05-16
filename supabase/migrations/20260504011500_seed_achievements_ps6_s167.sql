-- PS#6 S167: horseBodyCarryRatioBonus — 馬体重×斤量比補正 confidence 83 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S167: 競馬予測EF confidence 83 terms — horseBodyCarryRatioBonus追加',
  '馬体重×斤量比補正(horseBodyCarryRatioBonus)を追加。斤量(weight_kg)÷馬体重(horse_weight)の比率で相対的な負担重量を評価。①比率≥13%(例:57kg÷430kg=13.3%)=-1%(体力対比で高負担/消耗リスク)。②比率≤10%(例:53kg÷540kg=9.8%)=+1%(体格対比で軽斤量/スピード優位)。horseBodyWeightBonus(S59:絶対体重450-510kg帯)とweightKgBonus(S58:絶対斤量≤53kg/≥57kg)がそれぞれ単独評価するのに対し、本補正は両者の比率という組み合わせ指標で馬体への実質負担を評価。confidence formula 83 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
