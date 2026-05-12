-- PS#4 S479: 競合3社追加 1258→1261社 (nike-run-club/grubhub/waking-up)
-- SEO: "Nike Run Club代替"/"Grubhub代替"/"Waking Up代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S479: 競合3社追加 1258→1261社 (nike-run-club/grubhub/waking-up)',
  'comparison_page.dartにnike-run-club(Nike公式ランニングガイドランGPS Apple Watch/111111)/grubhub(米国フードデリバリーGrubhub+ Amazon Primeバンドル大学/F63440)/waking-up(Sam Harris科学的瞑想Daily Meditation無料アクセス制度/2C2C2E)の3社追加。sitemap 1354 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
