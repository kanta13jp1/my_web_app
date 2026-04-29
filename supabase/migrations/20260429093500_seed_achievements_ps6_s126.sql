-- PS#6 S126: popularityRankBonus (人気ランク補正) — confidence 42 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S126: 人気ランク補正 (popularityRankBonus) confidence 42 terms',
  '競馬予測EF confidence式に人気ランク補正(popularityRankBonus)を追加。1番人気=+1%(市場最高評価/的中確率高め)/7番人気以下=-1%(低人気=高リスク)/2〜6番人気=0(標準)。favOddsBonusやconsensusBonusと差別化した純粋な人気ランク単体補正。42 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
