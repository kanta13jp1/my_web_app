-- PS#4 S431: 競合3社追加 1117→1120社 (youtube-music/pocket-casts/audible)
-- SEO: "YouTube Music代替"/"Pocket Casts代替"/"Audible代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S431: 競合3社追加 1117→1120社 (youtube-music/pocket-casts/audible)',
  'comparison_page.dartにyoutube-music(8000万曲YouTube動画統合YouTube Premium同梱/music/FF0000)/pocket-casts(スマートスピード無音トリムクロスプラットフォーム同期/podcast/F43E37)/audible(Amazon傘下オーディオブックWhispersync月1クレジット/audiobook/F8991D)の3社追加(1117→1120社)。sitemap 1210 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
