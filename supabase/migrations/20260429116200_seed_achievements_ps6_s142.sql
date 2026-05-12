-- PS#6 S142: prevWinMarginBonus — 前走圧勝ボーナス confidence 58 terms
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S142: 競馬予測EF confidence 58 terms — prevWinMarginBonus追加',
  '前走1着かつ大差勝ち=+2%/3馬身以上=+1%のボーナスを追加。前走の勝利内容(着差)を信頼度に反映するシグナル。confidence formula 58 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
