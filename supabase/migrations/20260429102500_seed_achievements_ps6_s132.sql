-- PS#6 S132: prevRaceContextTrifectaBonus (前走コンテキスト三一致補正) — confidence 48 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S132: 前走コンテキスト三一致補正 (prevRaceContextTrifectaBonus) confidence 48 terms',
  '競馬予測EF confidence式に前走コンテキスト三一致補正(prevRaceContextTrifectaBonus)を追加。同会場(prevVenueMatch)×同距離(±100m内)×同コース種別の三一致=+2%。このレースを経験済みという最強の親しみシグナル。prevVenueMatchBonus/prevDistanceMatchBonus/courseTypeMatchBonusの個別補正との差別化。48 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
