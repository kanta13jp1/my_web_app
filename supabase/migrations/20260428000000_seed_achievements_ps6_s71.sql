-- PS#6 S71: evaluateHorsePredictionAccuracy N+1クエリ → バッチクエリ最適化
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S71 — evaluate_accuracy N+1クエリをバッチ化 (50レース: 100+クエリ→3クエリ)',
    'evaluateHorsePredictionAccuracy 関数内の N+1 DB クエリを Promise.all によるバッチクエリに置換。horse_entries と horse_race_predictions_ensemble をループ外で race_id IN (全レースID) で一括取得し、Map でインデックス化してループ内で O(1) ルックアップ。50レース評価時のDB ラウンドトリップが 100+ → 3 に削減。evaluate_accuracy の実行時間が大幅短縮され、毎時 JST 17-23時の自動実行でも Supabase connection limit に余裕が生まれる。',
    '2026-04-28'
  )
ON CONFLICT DO NOTHING;
