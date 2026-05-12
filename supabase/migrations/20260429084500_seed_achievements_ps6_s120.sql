-- PS#6 S120: prevLast3fBonus (前走上り3F補正) — confidence 36 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S120: 前走上り3F補正 (prevLast3fBonus) confidence 36 terms',
  '競馬予測EF confidence式に前走上り3F補正(prevLast3fBonus)を追加。≤34.0秒=+2%(優秀な末脚)/≤35.5秒=+1%(良好)/≥37.0秒=-1%(末脚不足リスク)/データなし=0。prevLast3FSlowPenaltyのソートロジックをconfidence式に統合。36 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
