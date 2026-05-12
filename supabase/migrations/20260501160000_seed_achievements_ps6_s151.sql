-- PS#6 S151: trainerTopCourseBonus — 調教師得意コースボーナス confidence 67 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S151: 競馬予測EF confidence 67 terms — trainerTopCourseBonus追加',
  '調教師の得意コース(trainer_top_course)と今回開催地が一致=+1%のボーナスを追加。騎手得意コース(S150)と対になる調教師視点の会場アドバンテージを信頼度に反映。confidence formula 67 terms体制確立。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
