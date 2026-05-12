-- PS#6 S110: jockeyWinRateBonus — 騎手勝率confidenceボーナス (26 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S110: 競馬予想モデル jockeyWinRateBonus (騎手勝率confidenceボーナス)',
  'jockeyWinRateBonus(topEntry)関数を追加。jockey_win_rateフィールドを使用。≥0.20=+0.03(トップジョッキー)/≥0.15=+0.02(好騎手)/≥0.10=+0.01(安定騎手)/それ以外=0。予想1位馬の騎手勝率をconfidenceに直接反映。confidence式に組み込み26 terms体制確立。reasoning文字列に「騎手勝率補正:+X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
