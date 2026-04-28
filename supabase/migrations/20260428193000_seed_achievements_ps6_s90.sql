-- PS#6 S90: 競馬予想モデル winningTimeCoverage (勝ち時計充足率) confidence追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S90: winningTimeCoverage — 勝ち時計データ充足率をconfidence計算に追加',
  'buildHistoricalBaselinePredictionにwinningTimeCoverage(winning_time充足率×0.01)を追加。confidence最終式(11 terms): 0.31+dataQuality*0.22+oddsCoverage*0.12+historyCoverage*0.07+bestTimeCoverage*0.05+prevMarginCoverage*0.03+jockeyCoverage*0.02+trainerCoverage*0.01+bloodlineCoverage*0.01+last3FCoverage*0.01+winningTimeCoverage*0.01-fieldPenalty+oddsGapBonus (grade cap適用)。勝ち時計データが揃うほど時計水準比較精度が向上。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
