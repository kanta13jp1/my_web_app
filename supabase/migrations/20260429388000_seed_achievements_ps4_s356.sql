-- PS#4 S356: 競合3社追加 939→942社 (pictory/fliki/invideo)
-- SEO: "Pictory代替"/"Fliki代替"/"InVideo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S356: 競合3社追加 939→942社 (pictory/fliki/invideo)',
  'comparison_page.dartにpictory(AIテキストto動画ブログ記事ビデオ自動生成/video-gen/7C3AED)/fliki(AIテキストto音声動画コンテンツ生成/video-gen/0EA5E9)/invideo(AIテキストto動画YouTubeコンテンツ/video-gen/0F172A)の3社追加(939→942社)。sitemap 985 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
