-- PS#6 S87: 競馬予想モデル jockeyCoverage + trainerCoverage confidence追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S87: jockeyCoverage+trainerCoverage — confidence計算に騎手/調教師データ充足率追加',
  'buildHistoricalBaselinePredictionにjockeyCoverage(*0.02)とtrainerCoverage(*0.01)を追加。confidence最終式: 0.31+dataQuality*0.22+oddsCoverage*0.12+historyCoverage*0.07+bestTimeCoverage*0.05+prevMarginCoverage*0.03+jockeyCoverage*0.02+trainerCoverage*0.01-fieldPenalty+oddsGapBonus (grade cap適用)。騎手・調教師データが揃うほど信頼度が向上。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
