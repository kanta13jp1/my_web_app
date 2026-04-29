-- PS#6 S128: prevFinishBonus (前走着順補正) — confidence 44 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S128: 前走着順補正 (prevFinishBonus) confidence 44 terms',
  '競馬予測EF confidence式に前走着順補正(prevFinishBonus)を追加。前走1着=+2%(連勝期待/最高フォーム)/前走2〜3着=+1%(好走継続)/前走7着以下=-1%(大敗/フォーム低下リスク)/4〜6着=0(標準)。recentFormBonus(着順×直近日数複合)・consensusBonus(人気×オッズ×着順の3指標)と差別化した純粋な前走着順単体補正。44 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
