-- PS#4 S190: 競合3社追加 441→444社 (wistia/vidyard/screenpal)
-- SEO: "Wistia代替"/"Vidyard代替"/"ScreenPal代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S190: 競合3社追加 441→444社 (wistia/vidyard/screenpal)',
  'comparison_page.dartにwistia(ビジネス動画ホスト/video/54BBFF)/vidyard(セールス動画/video/F36A31)/screenpal(画面録画/video/00CA9A)の3社追加(441→444社)。sitemap 487 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
