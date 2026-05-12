-- PS#6 S112: gradeDifficultyPenalty — グレード難易度confidenceペナルティ (28 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S112: 競馬予想モデル gradeDifficultyPenalty (グレード難易度confidenceペナルティ)',
  'gradeDifficultyPenalty(grade)関数を追加。G1=-0.03(超実力馬集結/展開不確実)/G2=-0.02/G3=-0.01/OP以下=0。重賞グレードの予測困難度をconfidenceに直接反映。reasoning文字列に「グレード補正:±X%」追加(G1時は-3%)。confidence式に組み込み28 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
