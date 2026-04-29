-- PS#6 S138: ageDistanceAffinityBonus (年齢×距離親和性補正) — confidence 54 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S138: 年齢×距離親和性補正 (ageDistanceAffinityBonus) confidence 54 terms',
  '競馬予測EF confidence式に年齢×距離親和性補正(ageDistanceAffinityBonus)を追加。3歳×長距離(2400m以上)=-1%(体力未成熟/スタミナ不確実/発達途上)。3歳×スプリント(1200m以下)=+1%(若い脚力/距離負担軽/短距離適性安定)。古馬(5歳以上)×中長距離(2000m以上)=+1%(経験豊富/スタミナ実証済み/予測容易)。ageOptimalBonusは年齢単独の補正だが本補正は年齢×距離の交互作用(interaction effect)を捉える複合シグナル。54 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
