-- PS#6 S107: bloodlineTopHorseBonus — 予想1位馬の血統充足でconfidenceボーナス (23 terms)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S107: 競馬予想モデル bloodlineTopHorseBonus (血統充足confidenceボーナス)',
  'bloodlineTopHorseBonus(topEntry)関数を追加。予想1位馬の血統3項目(sire+dam+damsire)完全充足=+0.02/父or母のみ=+0.01/なし=0。血統分析の深さがconfidenceに直結。confidence 23 terms体制確立。reasoning文字列に「血統充足:+X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
