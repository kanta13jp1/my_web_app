-- PS#6 S72: 競馬予想モデル強化 — Claude モデルID最新化 + ランキングアルゴリズム改善
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル強化: Claude最新化 + best_time/馬体重変動 ランキング追加',
  'tools-hub horseracing: (1) Claude モデルID最新化 — haiku→4-5-20251001, sonnet default→4-6, opus default→4-7。(2) sortHorseEntriesForLearning に best_time (持ち時計, 4番目因子) と horse_weight_change penalty (6番目因子) 追加。(3) timeToSecondsTS / weightChangeScore ヘルパー新規追加。(4) buildHistoricalBaselinePrediction confidence 式を best_time カバレッジ考慮に更新 (0.36→0.34ベース + bestTimeCoverage*0.05)。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
