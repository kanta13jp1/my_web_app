-- PS#4 S257: 競合3社追加 642→645社 (flagsmith/growthbook/doppler)
-- SEO: "Flagsmith代替"/"GrowthBook代替"/"Doppler代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S257: 競合3社追加 642→645社 (flagsmith/growthbook/doppler)',
  'comparison_page.dartにflagsmith(OSSフィーチャーフラグ/feature-flag/0E5FEC)/growthbook(OSS A/Bテスト+フラグ/feature-flag/9B59B6)/doppler(シークレット管理/security/4F46E5)の3社追加(642→645社)。sitemap 646 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
