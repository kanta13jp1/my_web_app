-- PS#6 S159: fieldWeightRankBonus — フィールド内斤量順位補正 confidence 75 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S159: 競馬予測EF confidence 75 terms — fieldWeightRankBonus追加',
  'フィールド内斤量順位補正(fieldWeightRankBonus)を追加。同レース全出走馬のweight_kgを比較し相対的斤量優位を評価。①フィールド最軽量=+1%(斤量面の相対的有利/スピード・スタミナへの負担最少)。②フィールド最重量=-1%(斤量面の相対的不利/最大負担)。weightKgBonus(S43:絶対斤量の軽重)が斤量の絶対値を見るのに対し、本補正は同フィールド内の相対順位を評価。entriesの全馬weight_kgを走査してminとmaxを特定。confidence formula 75 terms体制確立。',
  '2026-05-03'
) ON CONFLICT DO NOTHING;
