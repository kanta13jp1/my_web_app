-- PS#4 S153: 競合3社追加 330→333社 (pocket/instapaper/feedly)
-- SEO: "Pocket代替"/"Instapaper代替"/"Feedly代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S153: 競合3社追加 330→333社 (pocket/instapaper/feedly)',
  'comparison_page.dartにpocket(Mozilla後で読む/reading/EF4056)/instapaper(シンプル記事保存/reading/262626)/feedly(AI搭載RSSリーダー/reading/2BB24C)の3社追加(330→333社)。全ファイル339統一。sitemap 629 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
