-- PS#4 S207: 競合3社追加 492→495社 (smarthr/freee-hr/workday)
-- SEO: "SmartHR代替"/"freee人事労務代替"/"Workday代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S207: 競合3社追加 492→495社 (smarthr/freee-hr/workday)',
  'comparison_page.dartにsmarthr(日本HR/hr-jp/0077C7)/freee-hr(給与勤怠/hr-jp/2864F0)/workday(エンタープライズHR/hr/F1742E)の3社追加(492→495社)。sitemap 544 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
