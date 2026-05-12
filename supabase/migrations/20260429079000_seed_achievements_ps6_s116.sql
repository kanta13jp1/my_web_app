-- PS#6 S116: courseTypeMatchBonus — 前走コース種別一致confidenceボーナス (32 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S116: 競馬予想モデル courseTypeMatchBonus (前走コース種別一致confidenceボーナス)',
  'courseTypeMatchBonus(topEntry, currentCourseType)関数を追加。prev_course_typeとrace.course_typeを比較。同コース種別(芝→芝/ダート→ダート)=+0.02(実績あり/予測容易)/コース替わり(芝↔ダート)=-0.02(適性未知/不確実)/データなし=0。前走コース種別と今走の一致度がconfidenceに直接影響。confidence式に組み込み32 terms体制確立。reasoning文字列に「コース種別補正:±X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
