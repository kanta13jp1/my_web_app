-- PS#6 S158: courseSurfaceMatchBonus — コース種別前走一致補正 confidence 74 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S158: 競馬予測EF confidence 74 terms — courseSurfaceMatchBonus追加',
  'コース種別前走一致補正(courseSurfaceMatchBonus)を追加。current course_typeとtopEntry.prev_course_typeを比較。①前走と同じ馬場種別(芝/ダート/障害)=+1%(実績ある舞台で安心感/課題なし)。②前走と異なる馬場種別=-1%(馬場種別変更=未知の適性リスク)。bloodlineCourseTypeBonus(血統×コース適性)が血統起源の適性を見るのに対し、本補正は前走の実績起源の適性整合を評価。prev_course_typeフィールドを活用。confidence formula 74 terms体制確立。',
  '2026-05-03'
) ON CONFLICT DO NOTHING;
