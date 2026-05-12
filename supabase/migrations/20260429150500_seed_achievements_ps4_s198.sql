-- PS#4 S198: 競合3社追加 465→468社 (new-relic/dynatrace/grafana-cloud)
-- SEO: "New Relic代替"/"Dynatrace代替"/"Grafana代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S198: 競合3社追加 465→468社 (new-relic/dynatrace/grafana-cloud)',
  'comparison_page.dartにnew-relic(フルスタック監視/observability/008C99)/dynatrace(AI監視/observability/1496FF)/grafana-cloud(OSS可視化/observability/F46800)の3社追加(465→468社)。sitemap 511 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
