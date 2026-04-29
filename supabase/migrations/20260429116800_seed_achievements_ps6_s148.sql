-- PS#6 S148: raceClassStepBonus — クラス昇降補正 confidence 64 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S148: 競馬予測EF confidence 64 terms — raceClassStepBonus追加',
  '前走より格下クラス降格=+1%(有利条件)/格上昇格=-1%(不利条件)のボーナスを追加。レースクラスの昇降変化を信頼度に反映するシグナル。confidence formula 64 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
