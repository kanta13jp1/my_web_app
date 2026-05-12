-- PS#4 S237: 競合3社追加 582→585社 (datadog-apm/jaeger/opentelemetry)
-- SEO: "Datadog APM代替"/"Jaeger代替"/"OpenTelemetry代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S237: 競合3社追加 582→585社 (datadog-apm/jaeger/opentelemetry)',
  'comparison_page.dartにdatadog-apm(分散トレース/monitoring/632CA6)/jaeger(OSS分散トレース/monitoring/00B7F3)/opentelemetry(可観測性標準/monitoring/425CC7)の3社追加(582→585社)。sitemap 634 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
