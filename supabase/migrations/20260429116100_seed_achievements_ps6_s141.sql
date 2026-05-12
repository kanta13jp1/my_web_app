-- PS#6 S141: oddsFieldSpreadBonus (全馬オッズ分散補正) — confidence 57 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S141: 全馬オッズ分散補正 (oddsFieldSpreadBonus) confidence 57 terms',
  '競馬予測EF confidence式に全馬オッズ分散補正(oddsFieldSpreadBonus)を追加。オッズ最大値-最小値≥50倍=+1%(明確な本命存在/混戦度低/予測容易)。オッズ分散≤10倍=-1%(混戦/全馬に勝ちの可能性/予測困難)。favOddsBonusが最小オッズの絶対値を評価し、tightOddsPenaltyが上位2頭の近似を評価するのに対し、本補正はフィールド全体のオッズ広がりを評価するフィールドレベル指標。57 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
