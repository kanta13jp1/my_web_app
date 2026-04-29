-- PS#4 S511: 競合3社追加 継続 (loki/tempo/fluentd)
-- SEO: "Grafana Loki代替"/"Grafana Tempo代替"/"Fluentd代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S511: 競合3社追加 (loki/tempo/fluentd)',
  'comparison_page.dartにloki(Prometheus likeログ収集低コストインデックスなしGrafana統合/F46800)/tempo(分散トレーシング低コストJaeger/Zipkin互換Grafana統合/9B59B6)/fluentd(CNCF承認500+プラグイン統合ログレイヤーRuby/0E83CD)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
