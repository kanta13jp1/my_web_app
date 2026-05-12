-- PS#6 S83: 競馬予想モデル 馬体重絶対値ペナルティ (sort 13因子体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S83: weightKgOutlierPenalty — 馬体重絶対値sort因子追加',
  'weightKgOutlierPenalty新規追加: 430kg未満=+5(軽量リスク) / 560kg超=+4(重量リスク) / データなし=+2 / 適正範囲=0。sortHorseEntriesForLearning factor12として挿入(horse_number → 13のtiebreaker)。buildHorseRacePromptに馬体重絶対値リスク説明追加。sort13因子体制確立。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
