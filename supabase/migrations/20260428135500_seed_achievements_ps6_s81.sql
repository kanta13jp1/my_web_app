-- PS#6 S81: 競馬予想モデル コース適性ペナルティ (12因子目) + race context sort
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S81: courseDistancePenaltyScore (12因子目) + raceContext sort',
  'sortHorseEntriesForLearningにraceContext(courseType/distance)を追加。courseDistancePenaltyScore: コース種別替わり=+10 / 距離差400m+=+8 / 200-399m=+4。buildHistoricalBaselinePredictionからrace.course_type+race.distanceを渡す。sort12因子体制確立。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
