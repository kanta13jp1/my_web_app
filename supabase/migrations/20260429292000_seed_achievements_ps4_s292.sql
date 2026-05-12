-- PS#4 S292: 競合3社追加 747→750社 (impact-com/partnerstack/grin)
-- SEO: "Impact.com代替"/"PartnerStack代替"/"GRIN代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S292: 競合3社追加 747→750社 (impact-com/partnerstack/grin)',
  'comparison_page.dartにimpact-com(パートナーシップアフィリエイトインフルエンサー/affiliate/00C7B1)/partnerstack(SaaSパートナープログラム管理/affiliate/36B37E)/grin(eコマース特化インフルエンサーマーケ/influencer/5044E4)の3社追加(747→750社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
