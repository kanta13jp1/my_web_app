-- PS#4 S641: 競合3社追加 静的サイト生成 (hugo/jekyll/eleventy)
-- SEO: "Hugo代替"/"Jekyll代替"/"Eleventy代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S641: 競合3社追加 (hugo/jekyll/eleventy)',
  'comparison_page.dartにhugo(超高速静的サイト・Go製・テンプレート・Markdown・多言語・テーマ/FF4088)/jekyll(Ruby製静的サイト・GitHub Pages標準・Markdown/Liquid・ブログ/CC0000)/eleventy(シンプル静的サイト・多テンプレート対応・高速・独断なし/222222)の3社追加(1744社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
