-- PS#4 S471: 競合3社追加 1234→1237社 (pimsleur/goodreads/storygraph)
-- SEO: "Pimsleur代替"/"Goodreads代替"/"StoryGraph代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S471: 競合3社追加 1234→1237社 (pimsleur/goodreads/storygraph)',
  'comparison_page.dartにpimsleur(音声メソッド語学30分50+言語間隔反復/003087)/goodreads(Amazon傘下読書記録レビューチャレンジKindleシンク/372213)/storygraph(Goodreads代替多様性AI推薦Black-owned/1A1A2E)の3社追加(1234→1237社)。sitemap 1336 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
