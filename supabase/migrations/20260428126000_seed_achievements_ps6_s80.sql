-- PS#6 S80: 競馬予想モデル best_time品質18項目化 + グレード別confidence cap
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S80: best_time品質18項目化 + グレード別confidence cap',
  'horseRaceDataQualityScore に best_time 追加 (17→18フィールド)。gradeMaxConfidence 関数新規 (G1=0.65/G2=0.70/G3=0.75/その他=0.80)。buildHistoricalBaselinePrediction の confidence に grade cap 適用。重賞・G1は予測困難を誠実に反映。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
