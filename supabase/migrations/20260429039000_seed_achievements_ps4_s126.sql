-- PS#4 S126: 競合3社追加 249→252社 (teachable/kajabi/gumroad)
-- SEO: "Teachable代替"/"Kajabi代替"/"Gumroad代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S126: 競合3社追加 249→252社 (teachable/kajabi/gumroad)',
  'comparison_page.dartにteachable(オンラインコース販売/e-learning/00B87D)/kajabi(オールインワンオンラインビジネス/e-learning/6E3CFF)/gumroad(デジタル製品直販/digital-products/FF90E8)の3社追加(249→252社)。新カテゴリdigital-products追加。competitorMeta/sitemap/_categoryOf更新。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
