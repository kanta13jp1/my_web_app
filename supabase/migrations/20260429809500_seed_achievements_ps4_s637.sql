-- PS#4 S637: 競合3社追加 静的サイトドキュメント (mkdocs/vitepress/nextra)
-- SEO: "MkDocs代替"/"VitePress代替"/"Nextra代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S637: 競合3社追加 (mkdocs/vitepress/nextra)',
  'comparison_page.dartにmkdocs(Markdownドキュメント・Python製・Material for MkDocs・GitHub Pages/526CFE)/vitepress(Vite+Vue静的サイト・高速・Markdownドキュメント・Vue SFC/646CFF)/nextra(Next.js製ドキュメント・MDX・テーマ・Vercel統合/000000)の3社追加(1735社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
