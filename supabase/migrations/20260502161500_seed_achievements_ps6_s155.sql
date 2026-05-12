-- PS#6 S155: weightChangeCourseSuitBonus — 体重増減コース適合補正 confidence 71 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S155: 競馬予測EF confidence 71 terms — weightChangeCourseSuitBonus追加',
  '体重増減コース適合補正(weightChangeCourseSuitBonus)を追加。①ダートコースで体重+10kg以上増加=+1%(ダートはパワー型が有利/筋肉増強シグナル)。②芝コースで体重+20kg以上増加=-1%(芝は体重増=重め仕上げ警戒/斤量負担増)。horse_weight_changeとprev_course_typeフィールドを使用。日本競馬の馬場特性を反映した補正。confidence formula 71 terms体制確立。',
  '2026-05-02'
) ON CONFLICT DO NOTHING;
