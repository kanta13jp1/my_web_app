-- PS#6 S67: horseracing.stats EF — daily_trend フィールド同期 + aggregate 全期間集計追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S67 — horseracing.stats EF 全期間 aggregate 追加 + daily_trend 同期',
    'horseracing.stats の daily_trend に evaluated_races + wide_hit_rate_pct を追加 (S66 scraper 統計と同期)。aggregate フィールド新設: horse_bet_type_accuracy から全期間の total_evaluated / place_hit_rate_pct / tansho_hit_rate_pct / wide_hit_rate_pct / skip_accuracy_pct を集計。3 クエリを Promise.all で並列実行。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
