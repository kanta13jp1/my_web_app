-- PS#6 S169: ageGradeInteractionBonus — 馬齢×グレード難易度複合補正 confidence 85 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S169: 競馬予測EF confidence 85 terms — ageGradeInteractionBonus追加',
  '馬齢×グレード難易度複合補正(ageGradeInteractionBonus)を追加。age_sexフィールドから年齢を正規表現で抽出し、race.gradeと組み合わせて評価。①4-5歳(能力ピーク期) × G1/G2(最高峰グレード)=+1%(ピーク期の黄金コンビ)。②3歳 × G1=-1%(発展途上の若馬が古馬一線級のG1に挑む実力差リスク)。③7歳以上 × G1/G2=-1%(ピーク超え古馬が高難度グレードに挑む体力限界リスク)。ageOptimalBonus(S28:4-6歳一般最適期)が汎用的年齢補正を行うのに対し、本補正はグレード難易度という文脈を組み合わせた精密評価。ageDistanceAffinityBonus(S152:年齢×距離)との軸直交性確認済み。confidence formula 85 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
