-- PS#4 S214: 競合3社追加 513→516社 (tettra/guru/document360)
-- SEO: "Tettra代替"/"Guru代替"/"Document360代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S214: 競合3社追加 513→516社 (tettra/guru/document360)',
  'comparison_page.dartにtettra(AIナレッジ/kb/7C4DFF)/guru(AIカード配信/kb/6464FF)/document360(ナレッジベース/kb/0060FF)の3社追加(513→516社)。sitemap 562 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
