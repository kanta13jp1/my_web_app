-- PS#6 S76: prev_margin をデータ充足度スコアに追加 + baseline confidence に prevMarginCoverage 反映
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬AI: prev_margin データ品質スコア追加 + baseline confidence 改善',
  'horseRaceDataQualityScore の fields に prev_margin を追加 (15→16フィールド)。buildHistoricalBaselinePrediction に prevMarginCoverage 計算追加: 着差データあり率を confidence に反映 (base 0.34→0.31, +prevMarginCoverage*0.03 / 最大値 0.80 維持)。reasoning テキストに「着差」を明示追加。これにより着差データが充実しているレースほど基準予想の信頼度が向上する。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
