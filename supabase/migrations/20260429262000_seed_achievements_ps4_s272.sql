-- PS#4 S272: 競合3社追加 687→690社 (apollo/outreach/salesloft)
-- SEO: "Apollo.io代替"/"Outreach代替"/"Salesloft代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S272: 競合3社追加 687→690社 (apollo/outreach/salesloft)',
  'comparison_page.dartにapollo(セールスインテリジェンスリード生成/sales/7B2FBE)/outreach(セールスエンゲージメントパイプライン/sales/5522FA)/salesloft(セールスオーケストレーション収益/sales/00A0D1)の3社追加(687→690社)。sitemap 733 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
