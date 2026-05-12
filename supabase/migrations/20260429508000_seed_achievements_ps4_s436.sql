-- PS#4 S436: 競合3社追加 1132→1135社 (tidal/deezer/soundcloud)
-- SEO: "Tidal代替"/"Deezer代替"/"SoundCloud代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S436: 競合3社追加 1132→1135社 (tidal/deezer/soundcloud)',
  'comparison_page.dartにtidal(Jay-Z HiFi/Master音質アーティスト収益還元独占コンテンツ/music/000000)/deezer(フランス発9000万曲Flow AI推薦HiFi/music/A238FF)/soundcloud(インディーアーティストクリエイター配信Go+/music/FF5500)の3社追加(1132→1135社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
