-- PS#4 S169: 競合3社追加 378→381社 (contentful/strapi/sanity)
-- SEO: "Contentful代替"/"Strapi代替"/"Sanity代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S169: 競合3社追加 378→381社 (contentful/strapi/sanity)',
  'comparison_page.dartにcontentful(ヘッドレスCMS/cms/2478CC)/strapi(OSS CMS/cms/2F2BD6)/sanity(リアルタイム共同編集CMS/cms/F03E2F)の3社追加(378→381社)。sitemap 424 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
