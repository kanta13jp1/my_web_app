-- PS#4 S263: 競合3社追加 660→663社 (ironclad/trustpilot/yotpo)
-- SEO: "Ironclad代替"/"Trustpilot代替"/"Yotpo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S263: 競合3社追加 660→663社 (ironclad/trustpilot/yotpo)',
  'comparison_page.dartにironclad(AI契約管理CLM/legal/0E1E3C)/trustpilot(顧客レビュープラットフォーム/reviews/00B67A)/yotpo(eコマースレビュー+ロイヤルティ/ecommerce/0E4FFF)の3社追加(660→663社)。sitemap 664 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
