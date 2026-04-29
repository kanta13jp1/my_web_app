-- PS#4 S129: 競合3社追加 258→261社 (webex/capcut/davinci-resolve)
-- SEO: "Webex代替"/"CapCut代替"/"DaVinci Resolve代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S129: 競合3社追加 258→261社 (webex/capcut/davinci-resolve)',
  'comparison_page.dartにwebex(エンタープライズビデオ会議/video-comm/00BCEB)/capcut(AI搭載ショート動画編集/video-editing/1C1C1E)/davinci-resolve(プロ動画編集/video-editing/8B1A1A)の3社追加(258→261社)。新カテゴリvideo-editing追加。sitemap310URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
