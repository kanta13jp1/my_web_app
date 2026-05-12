-- PS#6 S125: sexCategoryBonus (性別補正) — confidence 41 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S125: 性別補正 (sexCategoryBonus) confidence 41 terms',
  '競馬予測EF confidence式に性別補正(sexCategoryBonus)を追加。セン馬(去勢)=+1%(気性安定/安定したパフォーマンス)/牝馬=-1%(牡馬混合レースでは統計的に不利)/牡馬=0(基準)。age_sexフィールド(例:4牡/5牝/3セン)からincludes検索で判定。41 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
