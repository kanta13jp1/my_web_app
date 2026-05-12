-- PS#6 S100: 競馬予想モデル recentFormBonus — 1強の直近好走をconfidence boostに追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S100: recentFormBonus — 1強の直近好走(30日以内3着以内)をconfidence boost',
  'buildHistoricalBaselinePredictionにrecentFormBonus(entries)を追加。最低オッズ馬(1番人気)が30日以内に3着以内 = +0.03 / 60日以内 = +0.01。1強が直近好走していれば予測信頼度上昇。confidence式: ...+oddsGapBonus+recentForm (grade cap適用)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
