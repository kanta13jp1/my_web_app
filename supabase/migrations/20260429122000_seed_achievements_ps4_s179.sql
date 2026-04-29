-- PS#4 S179: 競合3社追加 408→411社 (wave/harvest/bonsai)
-- SEO: "Wave代替"/"Harvest代替"/"Bonsai代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S179: 競合3社追加 408→411社 (wave/harvest/bonsai)',
  'comparison_page.dartにwave(無料会計/finance/1B998B)/harvest(時間追跡請求書/time-tracking/FA6321)/bonsai(フリーランス管理/freelance/00BFA5)の3社追加(408→411社)。sitemap 454 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
