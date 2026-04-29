-- PS#4 S200: 競合3社追加 471→474社 (algolia/elastic/typesense)
-- SEO: "Algolia代替"/"Elastic代替"/"Typesense代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S200: 競合3社追加 471→474社 (algolia/elastic/typesense)',
  'comparison_page.dartにalgolia(ホステッド検索/search/003DFF)/elastic(Elasticsearch統合/search/00BFB3)/typesense(OSS高速検索/search/D64242)の3社追加(471→474社)。sitemap 517 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
