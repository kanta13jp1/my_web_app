-- PS#6 S101: 競馬予想モデル reasoning文字列強化 — 馬体重/厩舎/人気coverage追加
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S101: reasoning文字列強化 — 馬体重/厩舎/人気のcoverage%を信頼度内訳に追加',
  'buildHistoricalBaselinePredictionのreasoningに馬体重(horseWeightCoverage)・厩舎(stableCoverage)・人気(popularityCoverage)の充足率%を追加。デバッグ透明性とユーザー向け情報密度が向上。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
