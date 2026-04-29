-- PS#4 S640: 競合3社追加 静的サイト生成 (astro/sveltekit/gatsby)
-- SEO: "Astro代替"/"SvelteKit代替"/"Gatsby代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S640: 競合3社追加 (astro/sveltekit/gatsby)',
  'comparison_page.dartにastro(コンテンツ重視・Islands Architecture・マルチFW・ゼロJS/FF5D01)/sveltekit(Svelteフルスタック・SSR/SSG・ファイルルーティング・Vite統合/FF3E00)/gatsby(React静的サイト・GraphQL・プラグイン・CMS統合・Netlify傘下/663399)の3社追加(1744社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
