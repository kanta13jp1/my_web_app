-- PS#6 S78: 競馬予想モデル 馬齢スコア (age_sex 11因子目)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '競馬予想モデル S78: 馬齢ペナルティ追加 (age_sex 11因子目)',
  '競馬AIランキングに馬齢ペナルティ (agePenaltyScore) を11因子目として追加。age_sex から年齢を抽出し3-5歳=0(最盛期)/6歳=3/7歳=8/8歳+=15/2歳以下=5(成長途上)/不明=5。sort因子を11に拡張。',
  '2026-04-28'
)
ON CONFLICT DO NOTHING;
