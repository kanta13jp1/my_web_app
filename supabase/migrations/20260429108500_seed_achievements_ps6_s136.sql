-- PS#6 S136: damSireLineBonus (母父系統×コース適性補正) — confidence 52 terms体制確立
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#6 S136: 母父系統×コース適性補正 (damSireLineBonus) confidence 52 terms',
  '競馬予測EF confidence式に母父系統×コース適性補正(damSireLineBonus)を追加。damsireフィールドから母父種牡馬系統を判定し芝/ダート適性を確認。芝系母父(サンデーサイレンス/ノーザンダンサー系9種)×芝レース=+1%(母系適性一致)。ダート系母父(ブライアンズタイム/フォーティーナイナー系7種)×ダートレース=+1%(母系適性一致)。芝系母父×ダートレース=-1%(逆適性懸念)。父系のbloodlineCourseTypeBonusとの二重チェックで適性信頼度を強化。52 terms体制確立。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
