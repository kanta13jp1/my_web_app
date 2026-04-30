-- PS#6 S130: jockeyTrainerComboBonus (騎手×調教師コンビ補正) — confidence 46 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S130: 騎手×調教師コンビ補正 (jockeyTrainerComboBonus) confidence 46 terms',
  '競馬予測EF confidence式に騎手×調教師コンビ補正(jockeyTrainerComboBonus)を追加。両者勝率15%以上=+2%(エリートコンビ最強シナジー)/両者10%以上=+1%(好コンビシナジー)/片方のみ=0(個別補正でカバー済み)。jockeyWinRateBonus/trainerWinRateBonusと差別化した両者同時好成績時の相乗効果評価。46 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
