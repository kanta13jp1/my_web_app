-- PS#6 S164: jockeyHorseReunionBonus — 騎手再コンビ補正 confidence 80 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S164: 競馬予測EF confidence 80 terms — jockeyHorseReunionBonus追加',
  '騎手再コンビ補正(jockeyHorseReunionBonus)を追加。current jockey_nameとprev_jockeyが同一騎手の場合に前走成績で評価。①同騎手かつ前走3着以内=+1%(成功コンビ再結成=馬との相性実証済み)。②同騎手かつ前走8着以下=-1%(失敗コンビ継続懸念=相性問題の継続リスク)。jockeyConsistencyBonus(S131:騎手乗り替わりなし+距離変化なし)が継続性を評価するのに対し、本補正は特定コンビの過去実績にフォーカス。confidence formula 80 terms体制確立。',
  '2026-05-04'
) ON CONFLICT DO NOTHING;
