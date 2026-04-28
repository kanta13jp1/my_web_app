-- PS#6 S102: 競馬予想モデル tightOddsPenalty — 超混戦レースにconfidenceペナルティ追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S102: tightOddsPenalty — 超混戦レース(オッズ上位3頭差<1倍)にconfidenceペナルティ',
  'buildHistoricalBaselinePredictionにtightOddsPenalty(entries)を追加。オッズ上位3頭のspread<1倍=-0.06/spread<2倍=-0.03。topTwoOddsGapBonusの逆軸として混戦レースの予測困難性を明示。confidence式: ...-fieldPenalty-tightOdds+oddsGapBonus+recentForm (grade cap適用)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
