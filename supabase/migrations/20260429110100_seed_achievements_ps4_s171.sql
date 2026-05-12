-- PS#4 S171: 競合3社追加 384→387社 (fly-io/render/digitalocean)
-- SEO: "Fly.io代替"/"Render代替"/"DigitalOcean代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S171: 競合3社追加 384→387社 (fly-io/render/digitalocean)',
  'comparison_page.dartにfly-io(エッジデプロイ/hosting/7B2FBE)/render(PaaS/hosting/46E3B7)/digitalocean(VPS/hosting/0080FF)の3社追加(384→387社)。sitemap 430 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
