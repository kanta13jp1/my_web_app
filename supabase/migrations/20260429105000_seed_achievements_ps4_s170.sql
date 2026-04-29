-- PS#4 S170: 競合3社追加 381→384社 (pocketbase/appwrite/directus)
-- SEO: "PocketBase代替"/"Appwrite代替"/"Directus代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S170: 競合3社追加 381→384社 (pocketbase/appwrite/directus)',
  'comparison_page.dartにpocketbase(SQLite BaaS/baas/B8C0FF)/appwrite(OSS統合BaaS/baas/FD366E)/directus(ノーコードDB/cms/6644FF)の3社追加(381→384社)。sitemap 427 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
