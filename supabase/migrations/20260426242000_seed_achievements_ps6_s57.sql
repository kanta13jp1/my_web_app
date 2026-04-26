-- PS#6 S57: horse_provider_leaderboard v2 + leaderboard EF bet_type enrichment
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S57: 競馬リーダーボード学習スコア対応',
  'horse_provider_leaderboard viewにavg_learning_score/skip_accuracy_pct追加。tools-hub EFにbest_bet_type/best_bet_hit_rate付加。VSCodeへUI更新cross-instance-pr起票。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
