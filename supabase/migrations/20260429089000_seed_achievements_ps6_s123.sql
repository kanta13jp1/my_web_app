-- PS#6 S123: horseBodyWeightBonus (馬体重補正) — confidence 39 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S123: 馬体重補正 (horseBodyWeightBonus) confidence 39 terms',
  '競馬予測EF confidence式に馬体重補正(horseBodyWeightBonus)を追加。450〜510kg=+1%(理想体重帯)/≤430kg=-1%(軽量リスク)/≥560kg=-1%(重量リスク)/その他=0。プロンプト記載の馬体重リスク基準をconfidence式に統合。39 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
