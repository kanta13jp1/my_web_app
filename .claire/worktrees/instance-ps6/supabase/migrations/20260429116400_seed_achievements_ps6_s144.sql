-- PS#6 S144: multipleTopSignalBonus — 複合シグナルボーナス confidence 60 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S144: 競馬予測EF confidence 60 terms — multipleTopSignalBonus追加',
  '人気1位/オッズ≤3/前走3着以内/騎手勝率≥15%/調教師勝率≥10%の5指標で4以上=+2%/3以上=+1%のボーナスを追加。複数独立シグナルが一致する場合の信頼度増幅。confidence formula 60 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
