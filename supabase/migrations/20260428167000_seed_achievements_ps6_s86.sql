-- PS#6 S86: 競馬予想モデル 1強レース判定 confidence boost
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S86: topTwoOddsGapBonus — 1強レース判定confidence boost',
  'topTwoOddsGapBonus新規追加: 1番人気vs2番人気オッズ差5倍以上=+0.05 / 3倍以上=+0.03 / 1.5倍以上=+0.01 / 混戦=0。buildHistoricalBaselinePredictionのconfidence計算に加算。buildHorseRacePromptに1強/混戦レース説明追加。confidence式: 0.31 + dataQuality*0.22 + oddsCoverage*0.12 + historyCoverage*0.07 + bestTimeCoverage*0.05 + prevMarginCoverage*0.03 - fieldPenalty + oddsGapBonus。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
