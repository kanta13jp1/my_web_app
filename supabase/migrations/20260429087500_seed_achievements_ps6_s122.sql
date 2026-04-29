-- PS#6 S122: prevMarginBonus (前走着差補正) — confidence 38 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S122: 前走着差補正 (prevMarginBonus) confidence 38 terms',
  '競馬予測EF confidence式に前走着差補正(prevMarginBonus)を追加。ハナ/アタマ/クビ=+1%(僅差健闘)/≤半馬身=+1%/≥5馬身=-1%(大敗)/大差=-2%(大敗強調)。marginPenaltyScoreの文字列解析を流用してconfidence式に統合。38 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
