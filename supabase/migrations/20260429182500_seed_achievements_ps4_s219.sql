-- PS#4 S219: 競合3社追加 528→531社 (magento/prestashop/ecwid)
-- SEO: "Magento代替"/"PrestaShop代替"/"Ecwid代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S219: 競合3社追加 528→531社 (magento/prestashop/ecwid)',
  'comparison_page.dartにmagento(Adobe Commerce/ecommerce/EE672F)/prestashop(OSS-EC/ecommerce/DF0067)/ecwid(軽量ECウィジェット/ecommerce/4CB4A0)の3社追加(528→531社)。sitemap 580 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
