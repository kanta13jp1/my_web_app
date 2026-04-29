-- PS#6 S119: prevDistanceMatchBonus (前走距離適合補正) — confidence 35 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S119: 前走距離適合補正 (prevDistanceMatchBonus) confidence 35 terms',
  '競馬予測EF confidence式に前走距離適合補正(prevDistanceMatchBonus)を追加。前走±100m以内=+1%(距離経験・適性実証)/前走±300m超=-1%(大幅距離変更リスク)/その他=0。confidence式35 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
