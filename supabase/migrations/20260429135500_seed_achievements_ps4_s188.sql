-- PS#4 S188: 競合3社追加 435→438社 (chartmogul/baremetrics/profitwell)
-- SEO: "ChartMogul代替"/"Baremetrics代替"/"ProfitWell代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S188: 競合3社追加 435→438社 (chartmogul/baremetrics/profitwell)',
  'comparison_page.dartにchartmogul(SaaS収益分析/saas-analytics/41B3F9)/baremetrics(Stripe収益ダッシュ/saas-analytics/F5A623)/profitwell(Paddle無料分析/saas-analytics/3DDC97)の3社追加(435→438社)。sitemap 481 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
