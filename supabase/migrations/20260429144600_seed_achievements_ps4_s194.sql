-- PS#4 S194: 競合3社追加 453→456社 (paddle/chargebee/lemonsqueezy)
-- SEO: "Paddle代替"/"Chargebee代替"/"Lemon Squeezy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S194: 競合3社追加 453→456社 (paddle/chargebee/lemonsqueezy)',
  'comparison_page.dartにpaddle(SaaS MoR決済/payment/1A56DB)/chargebee(サブスク請求/payment/FF5A00)/lemonsqueezy(デジタル商品決済/payment/FFCE37)の3社追加(453→456社)。sitemap 499 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
