-- PS#6 S84: 競馬予想モデル 前走タイムvsbest_timeギャップペナルティ (sort 14因子体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S84: prevTimeGapPenalty — 前走タイムvsbest_time乖離sort因子追加',
  'prevTimeGapPenalty新規追加: prev_timeがbest_timeより3秒以上遅い=+6 / 2-3秒=+4 / 1-2秒=+2 / 1秒以内=0。データなしは0(安全フォールバック)。sortHorseEntriesForLearning factor13として挿入(horse_number → 14のtiebreaker)。buildHorseRacePromptに前走タイム乖離リスク説明追加。sort14因子体制確立。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
