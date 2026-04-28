-- PS#6 S95: 競馬予想モデル horseWeightCoverage (馬体重充足率) confidence追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S95: horseWeightCoverage — 馬体重データ充足率をconfidence計算に追加',
  'buildHistoricalBaselinePredictionにhorseWeightCoverage(horse_weight充足率×0.01)を追加。confidence最終式(15 terms): 0.31+dataQuality*0.22+oddsCoverage*0.12+historyCoverage*0.07+bestTimeCoverage*0.05+prevMarginCoverage*0.03+jockeyCoverage*0.02+trainerCoverage*0.01+bloodlineCoverage*0.01+last3FCoverage*0.01+winningTimeCoverage*0.01+weightChangeCoverage*0.01+ageCoverage*0.01+sexCoverage*0.01+horseWeightCoverage*0.01-fieldPenalty+oddsGapBonus (grade cap適用)。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
