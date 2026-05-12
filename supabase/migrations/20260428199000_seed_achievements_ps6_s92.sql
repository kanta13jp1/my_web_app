-- PS#6 S92: 競馬予想モデル prevLast3FSlowPenalty sort16因子目追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S92: prevLast3FSlowPenalty — ラスト3F遅い馬へのペナルティ (sort 16因子体制)',
  'sortHorseEntriesForLearningにprevLast3FSlowPenalty(prev_last_3f: 37秒+=+6/36秒+=+4/35秒+=+2/データなし=+2)を15番目因子として追加(horse_numberは16に繰り上げ)。末脚が遅い馬を予想外から除外しやすくなる。sort 16因子体制確立。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
