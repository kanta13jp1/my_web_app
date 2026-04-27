-- PS#6 S62: horse ranking algorithm improvement — prev_last_3f tiebreaker + data quality
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'PS#6 S62 — 競馬ランキング精度向上 (prev_last_3f)',
    'sortHorseEntriesForLearning に prev_last_3f (上り3F タイム) をタイブレーカー追加。prev_finish 同着時に上りタイムが速い馬を優先。horseRaceDataQualityScore のフィールドにも prev_last_3f を追加 (13→14 フィールド)。learning_score の複勝命中率向上が期待値。',
    '2026-04-27'
  )
ON CONFLICT DO NOTHING;
