-- PS#4 S210: 競合3社追加 501→504社 (new-relic/splunk/pagerduty)
-- SEO: "New Relic代替"/"Splunk代替"/"PagerDuty代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S210: 競合3社追加 501→504社 (new-relic/splunk/pagerduty)',
  'comparison_page.dartにnew-relic(APM可観測性/monitoring/1CE783)/splunk(ログSIEM/monitoring/FF6666)/pagerduty(インシデント管理/monitoring/25C151)の3社追加(501→504社)。sitemap 553 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
