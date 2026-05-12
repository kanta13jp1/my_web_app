-- PS#4 S227: 競合3社追加 552→555社 (convex/pocketbase/hasura)
-- SEO: "Convex代替"/"PocketBase代替"/"Hasura代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S227: 競合3社追加 552→555社 (convex/pocketbase/hasura)',
  'comparison_page.dartにconvex(リアクティブDB/baas/EE342F)/pocketbase(1バイナリBaaS/baas/16161E)/hasura(GraphQL自動生成/baas/1EB4D4)の3社追加(552→555社)。sitemap 598 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
