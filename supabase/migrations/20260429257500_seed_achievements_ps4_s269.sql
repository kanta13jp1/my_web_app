-- PS#4 S269: 競合3社追加 678→681社 (raindrop-io/habitify/structured-app)
-- SEO: "Raindrop代替"/"Habitify代替"/"Structured代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S269: 競合3社追加 678→681社 (raindrop-io/habitify/structured-app)',
  'comparison_page.dartにraindrop-io(スマートブックマーク管理/bookmark/2196F3)/habitify(データドリブン習慣追跡iOS/habit/5B4CF5)/structured-app(ビジュアル1日タイムブロック/productivity/FF6B35)の3社追加(678→681社)。sitemap 724 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
