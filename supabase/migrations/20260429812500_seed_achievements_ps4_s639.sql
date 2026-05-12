-- PS#4 S639: 競合3社追加 メタフレームワーク (nextjs/nuxt/remix)
-- SEO: "Next.js代替"/"Nuxt代替"/"Remix代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S639: 競合3社追加 (nextjs/nuxt/remix)',
  'comparison_page.dartにnextjs(React SSR/SSG/ISR・App Router・Vercel製・フルスタック/000000)/nuxt(Vue SSR/SSG/ISR・Nitro・自動インポート・TypeScript/00DC82)/remix(React Routerベース・Web標準重視・ネストレイアウト・Shopify傘下/E8F2FF)の3社追加(1744社)。sitemap 1840 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
