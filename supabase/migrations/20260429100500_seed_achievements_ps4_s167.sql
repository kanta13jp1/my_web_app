-- PS#4 S167: 競合3社追加 372→375社 (woocommerce/bigcommerce/railway)
-- SEO: "WooCommerce代替"/"BigCommerce代替"/"Railway代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S167: 競合3社追加 372→375社 (woocommerce/bigcommerce/railway)',
  'comparison_page.dartにwoocommerce(WordPress EC/ecommerce/96588A)/bigcommerce(大規模EC/ecommerce/34313F)/railway(クラウドホスティング/devtools/0B0D0E)の3社追加(372→375社)。sitemap 418 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
