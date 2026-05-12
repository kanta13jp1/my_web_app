-- PS#6 S88: 競馬予想モデル bloodlineCoverage confidence追加 + reasoning詳細化
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S88: bloodlineCoverage — 血統データ充足率をconfidence計算に追加 + reasoning詳細ログ',
  'buildHistoricalBaselinePredictionにbloodlineCoverage(sireフィールド充足率×0.01)を追加。confidence最終式: 0.31+dataQuality*0.22+oddsCoverage*0.12+historyCoverage*0.07+bestTimeCoverage*0.05+prevMarginCoverage*0.03+jockeyCoverage*0.02+trainerCoverage*0.01+bloodlineCoverage*0.01-fieldPenalty+oddsGapBonus (grade cap適用)。reasoningに信頼度内訳(データ充足/オッズ/血統/騎手/頭数/グレード)を追記。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
