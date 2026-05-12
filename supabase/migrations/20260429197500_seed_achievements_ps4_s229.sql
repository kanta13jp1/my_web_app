-- PS#4 S229: 競合3社追加 558→561社 (grafana/prometheus/sentry)
-- SEO: "Grafana代替"/"Prometheus代替"/"Sentry代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S229: 競合3社追加 558→561社 (grafana/prometheus/sentry)',
  'comparison_page.dartにgrafana(可観測性ダッシュボード/monitoring/FF6D00)/prometheus(OSSメトリクス収集/monitoring/E75225)/sentry(エラー監視/monitoring/362D59)の3社追加(558→561社)。sitemap 607 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
