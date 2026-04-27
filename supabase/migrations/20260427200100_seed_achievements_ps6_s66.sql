-- PS#6 S66: print_learning_stats 出力強化 — 期間サマリー + wide_hit_rate + evaluated_races
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S66 — 競馬学習統計レポート強化 (期間サマリー + ワイド率 + レース数)',
    'print_learning_stats に期間サマリー行追加 (合計予想数/レース数/期間平均スコア/2日トレンド矢印)。daily表に evaluated_races + wide_hit_rate_pct カラム追加。GITHUB_STEP_SUMMARY も同様に8カラム化。horse_learning_daily_accuracy の wide_hit_rate_pct 列を初めて活用。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
