-- PS#6 S124: prevTimeGapBonus (前走タイム vs 持ち時計補正) — confidence 40 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S124: 前走タイム差補正 (prevTimeGapBonus) confidence 40 terms',
  '競馬予測EF confidence式に前走タイム差補正(prevTimeGapBonus)を追加。前走タイムが持ち時計(best_time)より≥2秒遅い=-1%(調子落ちリスク)/≤0.3秒=+1%(好調維持)/その他=0。プロンプト記載「2秒以上遅い=調子落ち」基準をconfidence式に統合。timeToSecondsTS関数活用。40 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
