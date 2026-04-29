-- PS#6 S118: prevVenueMatchBonus (前走同会場補正) — confidence 34 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S118: 前走同会場補正 (prevVenueMatchBonus) confidence 34 terms',
  '競馬予測EF confidence式に前走同会場補正(prevVenueMatchBonus)を追加。前走と今走が同一会場の場合=+1%(コース経験・適性実証あり)、異会場=0。prevVenueMatchScoreの知識をconfidence式に統合。34 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
