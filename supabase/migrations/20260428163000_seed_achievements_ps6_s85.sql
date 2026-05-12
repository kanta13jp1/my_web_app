-- PS#6 S85: 競馬予想モデル 連闘/中1週疲労ペナルティ (sort 15因子体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S85: tooFrequentRacePenalty — 連闘/中1週疲労リスクsort因子追加',
  'tooFrequentRacePenalty新規追加: 連闘(≤7日)=+8(疲労リスク最大) / 中1週(≤13日)=+4 / 中2週以上=0。freshnessPenalty(長休み)と対をなす出走間隔リスク軸。sortHorseEntriesForLearning factor14として挿入(horse_number → 15のtiebreaker)。buildHorseRacePromptに連闘/中1週リスク説明追加。sort15因子体制確立。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
