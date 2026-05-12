-- PS#6 S131: topHorseDataCompletenessBonus (最高位馬データ完全性補正) — confidence 47 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S131: 最高位馬データ完全性補正 (topHorseDataCompletenessBonus) confidence 47 terms',
  '競馬予測EF confidence式に最高位馬データ完全性補正(topHorseDataCompletenessBonus)を追加。predicted winner(first)自身の10キーフィールド(jockey/trainer/win_odds/popularity/age_sex/horse_weight/weight_kg/prev_finish/prev_time/prev_last_3f)充足数で評価。全10項目=+2%/7〜9項目=+1%。フィールド全体平均のdataQualityと差別化した予測対象馬固有の評価材料完全性評価。47 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
