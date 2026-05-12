-- PS#6 S115: raceIntervalBonus — 前走間隔最適期confidenceボーナス (31 terms体制)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S115: 競馬予想モデル raceIntervalBonus (前走間隔最適期confidenceボーナス)',
  'raceIntervalBonus(topEntry)関数を追加。prev_days_agoフィールドを使用。7〜35日=+0.01(最適間隔/仕上がり安定/予測容易)/≤6日=-0.01(超短期連闘/疲労懸念)/≥91日=-0.01(長期休み明け/本来形不明)/36〜90日=0(標準)。前走からの休養間隔がconfidenceに直接影響。confidence式に組み込み31 terms体制確立。reasoning文字列に「間隔補正:±X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
