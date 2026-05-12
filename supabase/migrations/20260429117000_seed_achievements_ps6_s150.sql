-- PS#6 S150: jockeyTopCourseBonus — 騎手得意コースボーナス confidence 66 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S150: 競馬予測EF confidence 66 terms — jockeyTopCourseBonus追加',
  '騎手の得意コース(jockey_top_course)と今回開催地が一致=+1%のボーナスを追加。騎手固有の得意会場アドバンテージを信頼度に反映するシグナル。confidence formula 66 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
