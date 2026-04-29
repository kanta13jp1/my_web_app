-- PS#6 S134: bestTimeFieldRankBonus (フィールドベストタイム順位補正) — confidence 50 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S134: フィールドベストタイム順位補正 (bestTimeFieldRankBonus) confidence 50 terms',
  '競馬予測EF confidence式にフィールドベストタイム順位補正(bestTimeFieldRankBonus)を追加。出走全頭のbest_timeを比較し、本命馬がフィールド最速ベストタイム保持=+2%。0.5秒差以内=+1%。2秒以上劣後=-1%。単独の最高ベストではなく全馬との相対比較で実力差を定量化。データが1頭以下の場合はスキップ(null安全)。50 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
