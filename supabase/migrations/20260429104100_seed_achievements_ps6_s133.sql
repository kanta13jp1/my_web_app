-- PS#6 S133: bloodlineCourseTypeBonus (血統コース種別適性補正) — confidence 49 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S133: 血統コース種別適性補正 (bloodlineCourseTypeBonus) confidence 49 terms',
  '競馬予測EF confidence式に血統コース種別適性補正(bloodlineCourseTypeBonus)を追加。芝適性上位種牡馬(ディープインパクト/ハービンジャー/エピファネイア他8頭)が芝レース出走=+1%。ダート適性上位種牡馬(ゴールドアリュール/パイロ/ヘニーヒューズ他7頭)がダートレース出走=+1%。逆適性(芝系がダート・ダート系が芝)=-1%。血統×コース種別の掛け合わせで適性を数値化。49 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
