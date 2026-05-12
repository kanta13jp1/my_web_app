-- PS#4 S228: 競合3社追加 555→558社 (cloudflare/fastly/bunny-net)
-- SEO: "Cloudflare代替"/"Fastly代替"/"Bunny.net代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S228: 競合3社追加 555→558社 (cloudflare/fastly/bunny-net)',
  'comparison_page.dartにcloudflare(CDN/DDoS/エッジ/cdn/F38020)/fastly(リアルタイムCDN/cdn/FF282D)/bunny-net(コスト効率CDN/cdn/F0641E)の3社追加(555→558社)。sitemap 607 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
