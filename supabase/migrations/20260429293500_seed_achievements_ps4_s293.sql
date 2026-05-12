-- PS#4 S293: 競合3社追加 750→753社 (talkwalker/cision/upfluence)
-- SEO: "Talkwalker代替"/"Cision代替"/"Upfluence代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S293: 競合3社追加 750→753社 (talkwalker/cision/upfluence)',
  'comparison_page.dartにtalkwalker(AIソーシャルリスニングコンシューマーインテリジェンス/pr/F53D3D)/cision(PR配信メディア監視ジャーナリストDB/pr/E4002B)/upfluence(データ駆動インフルエンサー発見/influencer/34A853)の3社追加(750→753社)。sitemap 796 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
