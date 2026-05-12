-- PS#4 S318: 競合3社追加 825→828社 (hashnode/astro-build/render-com)
-- SEO: "Hashnode代替"/"Astro代替"/"Render代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S318: 競合3社追加 825→828社 (hashnode/astro-build/render-com)',
  'comparison_page.dartにhashnode(開発者向けブログテックコミュニティ/blog/2962FF)/astro-build(Islands Architecture高速コンテンツサイト/framework/FF5D01)/render-com(フルスタッククラウドホスティング/hosting/46E3B7)の3社追加(825→828社)。sitemap 877 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
