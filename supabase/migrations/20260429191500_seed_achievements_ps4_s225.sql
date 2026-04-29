-- PS#4 S225: 競合3社追加 546→549社 (planetscale/neon/turso)
-- SEO: "PlanetScale代替"/"Neon代替"/"Turso代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S225: 競合3社追加 546→549社 (planetscale/neon/turso)',
  'comparison_page.dartにplanetscale(サーバーレスMySQL/serverless-db/000000)/neon(サーバーレスPG/serverless-db/00E5BF)/turso(エッジSQLite/serverless-db/4FF8D2)の3社追加(546→549社)。sitemap 598 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
