-- PS#6 S104: favOddsBonus — 圧倒的本命の絶対オッズconfidenceボーナス
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S104: 競馬予想モデル favOddsBonus (本命オッズconfidenceボーナス)',
  'favOddsBonus(entries)関数を追加。1番人気単勝オッズ絶対値でconfidence boost: ≤1.5倍=+0.05(圧倒的本命)/≤2.0倍=+0.03(強本命)/≤3.0倍=+0.01(本命)。topTwoOddsGapBonus(相対差)と直交する絶対値指標。21 terms体制確立。reasoning文字列に「本命補正:+X%」追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
