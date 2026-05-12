-- PS#6 S111: trainerWinRateBonus — 調教師勝率confidenceボーナス (27 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S111: 競馬予想モデル trainerWinRateBonus (調教師勝率confidenceボーナス)',
  'trainerWinRateBonus(topEntry)関数を追加。trainer_win_rateフィールドを使用。≥0.15=+0.02(トップトレーナー)/≥0.10=+0.01(好調教師)/それ以外=0。jockeyWinRateBonusの対称軸として調教師実績をconfidenceに反映。confidence式に組み込み27 terms体制確立。reasoning文字列に「調教師勝率補正:+X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
