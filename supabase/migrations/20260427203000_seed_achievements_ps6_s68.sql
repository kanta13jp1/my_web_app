-- PS#6 S68: --mode dqs_recalc — 既存 data_quality_score を 15フィールドで再計算
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S68 — data_quality_score 再計算モード (dqs_recalc)',
    'fetch_horse_racing.py に --mode dqs_recalc 追加。prev_history_fetched=true の horse_entries の data_quality_score を S62/S63 で追加した 15 フィールド定義で再計算して DB 更新。スコアが 0.001 以上変化したエントリのみ PATCH するため効率的。GHA workflow_dispatch description にも追加。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
