-- PS#4 S176: 競合3社追加 399→402社 (visme/pitch/gamma)
-- SEO: "Visme代替"/"Pitch代替"/"Gamma代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S176: 競合3社追加 399→402社 (visme/pitch/gamma)',
  'comparison_page.dartにvisme(AIインフォグラフィック/design/6C2EB9)/pitch(共同プレゼン/presentation/3D3D8C)/gamma(AIスライド生成/presentation/7C3AED)の3社追加(399→402社)。sitemap 445 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
