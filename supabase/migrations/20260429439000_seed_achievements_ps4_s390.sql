-- PS#4 S390: 競合3社追加 1041→1044社 (recurly/zuora/fastspring)
-- SEO: "Recurly代替"/"Zuora代替"/"FastSpring代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S390: 競合3社追加 1041→1044社 (recurly/zuora/fastspring)',
  'comparison_page.dartにrecurly(サブスク管理請求自動化収益最大化/subscription/8B17FF)/zuora(エンタープライズサブスク請求収益認識/subscription/00A8E0)/fastspring(ソフトウェアSaaS向けeコマース決済/ecommerce/2BAC76)の3社追加(1041→1044社)。sitemap 1093 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
