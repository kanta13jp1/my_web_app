-- PS#4 S357: 競合3社追加 942→945社 (vimeo/brightcove/dailymotion)
-- SEO: "Vimeo代替"/"Brightcove代替"/"Dailymotion代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S357: 競合3社追加 942→945社 (vimeo/brightcove/dailymotion)',
  'comparison_page.dartにvimeo(プロ向け動画ホスティング共有AIプラットフォーム/video-hosting/1AB7EA)/brightcove(エンタープライズ動画ライブストリーミング/video-hosting/0099CC)/dailymotion(動画ホスティング配信メディアAPI/video-hosting/003366)の3社追加(942→945社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
