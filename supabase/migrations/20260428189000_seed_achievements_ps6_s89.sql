-- PS#6 S89: 競馬予想モデル last3FCoverage (上がり3ハロン充足率) confidence追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S89: last3FCoverage — 上がり3ハロンデータ充足率をconfidence計算に追加',
  'buildHistoricalBaselinePredictionにlast3FCoverage(prev_last_3f充足率×0.01)を追加。confidence最終式(10 terms): 0.31+dataQuality*0.22+oddsCoverage*0.12+historyCoverage*0.07+bestTimeCoverage*0.05+prevMarginCoverage*0.03+jockeyCoverage*0.02+trainerCoverage*0.01+bloodlineCoverage*0.01+last3FCoverage*0.01-fieldPenalty+oddsGapBonus (grade cap適用)。reasoning内訳に上がり3F充足率を追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
