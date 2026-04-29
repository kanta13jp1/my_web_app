-- PS#6 S106: smallFieldBonus — 少頭数レースconfidenceボーナス (22 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S106: 競馬予想モデル smallFieldBonus (少頭数レースconfidenceボーナス)',
  'smallFieldBonus(fieldSize)関数を追加。≤4頭=+0.04/≤6頭=+0.02/≤8頭=+0.01/9頭以上=0。fieldSizeConfidencePenalty(大型レースペナルティ)の逆軸として少頭数レースの予測容易性を反映。confidence式に組み込み22 terms体制確立。reasoning文字列に「少頭数補正:+X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
