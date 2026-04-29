-- PS#4 S606: 競合3社追加 継続 (elastic-apm/lightstep/uptrace)
-- SEO: "Elastic APM代替"/"Lightstep代替"/"Uptrace代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S606: 競合3社追加 (elastic-apm/lightstep/uptrace)',
  'comparison_page.dartにelastic-apm(APM・分散トレーシング・エラー追跡・Elastic Stack統合/00BFB3)/lightstep(分散トレーシング・OpenTelemetry・変更インテリジェンス・ServiceNow/0059FF)/uptrace(OpenTelemetry APM・トレーシング・メトリクス・ログ・OSS/6366F1)の3社追加(1645社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
