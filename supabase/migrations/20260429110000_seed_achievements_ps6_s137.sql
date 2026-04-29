-- PS#6 S137: popularityOddsAlignBonus (人気×オッズ整合性補正) — confidence 53 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S137: 人気×オッズ整合性補正 (popularityOddsAlignBonus) confidence 53 terms',
  '競馬予測EF confidence式に人気×オッズ整合性補正(popularityOddsAlignBonus)を追加。1番人気×単勝2倍以下=+1%(市場の強い合意/投票と市場評価が完全一致/予測容易)。1番人気×単勝5倍超=-1%(人気と市場の乖離/投票者と賭け手の意見不一致/不確実)。上位3番人気×単勝8倍超=-1%(市場の過大評価懸念/実力疑問)。popularityRankBonusは人気単独の補正だが本補正はオッズとの複合シグナルで市場のコンセンサス強度を測定。53 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
