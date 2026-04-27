-- PS#6 S75: 前走着差(prev_margin) 9因子目追加 + AIプロンプト着差評価明示
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬AI: prev_margin 9因子目追加 + 着差プロンプト明示',
  'marginPenaltyScore()関数新規追加: 大差=30pt/ハナ・アタマ=1pt/クビ=2pt/分数馬身=比例/数値=比例(max30)。sortHorseEntriesForLearningを8→9因子化(前走着順の直後にprev_margin penaltyを4番目として挿入)。formatHorseEntryForPromptの前走情報に着差${e.prev_margin}を表示追加。buildHorseRacePromptのプロンプトテキストに「前走着差が大差なら評価ダウン、ハナ/クビ差なら健闘」の評価ルールを明示。evaluateHorsePredictionAccuracyのfeaturesリストに「前走着差」追加。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
