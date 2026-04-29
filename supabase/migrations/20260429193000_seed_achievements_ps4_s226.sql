-- PS#4 S226: 競合3社追加 549→552社 (upstash/xata/appwrite)
-- SEO: "Upstash代替"/"Xata代替"/"Appwrite代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S226: 競合3社追加 549→552社 (upstash/xata/appwrite)',
  'comparison_page.dartにupstash(サーバーレスRedis/Kafka/serverless-db/00E9A3)/xata(サーバーレスDB+AI/serverless-db/9F2DEC)/appwrite(OSSBaaS/baas/F02E65)の3社追加(549→552社)。sitemap 598 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
