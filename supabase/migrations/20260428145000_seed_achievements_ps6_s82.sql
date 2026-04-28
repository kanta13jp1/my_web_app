-- PS#6 S82: 競馬予想モデル 出走頭数confidence penalty (13因子目)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S82: fieldSizeConfidencePenalty — 出走頭数別confidence調整',
  'fieldSizeConfidencePenalty新規追加: 16頭以上=-0.07 / 13-15頭=-0.04 / 9-12頭=-0.02 / ≤8頭=0。buildHistoricalBaselinePredictionのconfidence計算に適用。buildHorseRacePromptに出走頭数リスク説明+頭数表示追加(13頭以上=中型レース波乱注意/16頭以上=大型レース高波乱リスク)。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
