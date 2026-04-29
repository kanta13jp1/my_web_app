-- PS#6 S135: popularityPrevFinishConsistencyBonus (人気前走着順整合性補正) — confidence 51 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S135: 人気前走着順整合性補正 (popularityPrevFinishConsistencyBonus) confidence 51 terms',
  '競馬予測EF confidence式に人気前走着順整合性補正(popularityPrevFinishConsistencyBonus)を追加。1番人気×前走3着以内=+2%(安定した実力馬/二重確認)。上位3番人気×前走1着=+1%(連勝気配)。1番人気×前走6着以下=-2%(調子落ちリスク大)。上位3番人気×前走8着以下=-1%(状態不安)。単独の人気や着順でなく「市場評価×直近結果の整合性」を見る複合シグナル。51 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
