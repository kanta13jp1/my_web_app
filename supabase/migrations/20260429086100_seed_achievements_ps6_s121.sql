-- PS#6 S121: weightKgBonus (斤量補正) — confidence 37 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S121: 斤量補正 (weightKgBonus) confidence 37 terms',
  '競馬予測EF confidence式に斤量補正(weightKgBonus)を追加。≤53kg=+1%(軽斤量有利)/54〜56kg=0(標準)/≥57kg=-1%(重斤量不利)。weightKgPenaltyScoreのソートロジックをconfidence式に統合。37 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
