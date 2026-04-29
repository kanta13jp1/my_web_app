-- PS#4 S349: 競合3社追加 918→921社 (moises/soundraw/beatoven-ai)
-- SEO: "Moises代替"/"Soundraw代替"/"Beatoven代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S349: 競合3社追加 918→921社 (moises/soundraw/beatoven-ai)',
  'comparison_page.dartにmoises(AIミュージシャン練習ステム分離リミックス/audio-tools/10B981)/soundraw(AI音楽生成ロイヤリティフリーBGMカスタマイズ/music-gen/1F2937)/beatoven-ai(AIテキストto音楽感情ムード駆動楽曲/music-gen/7C3AED)の3社追加(918→921社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
