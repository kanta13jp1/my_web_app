-- PS#4 S667: 競合9社追加 パフォーマンステストツール (k6/JMeter/Gatling/Locust/Artillery/BlazeMeter/Vegeta/hey/NeoLoad)
-- SEO: "k6代替"/"JMeter代替"/"負荷テスト代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S667: 競合9社追加 (k6/JMeter/Gatling/Locust/Artillery/BlazeMeter/Vegeta/hey/NeoLoad)',
  'comparison_page.dartにk6(Grafana/Go製/JS・TS/Prometheus連携/7B4FFF)/Apache JMeter(Java製/HTTP・JDBC・SOAP/分散/D22128)/Gatling(Scala・Kotlin/非同期Akka/HTMLレポート/FF5100)/Locust(Python/分散/Web UI/4CAF50)/Artillery(Node.js/YAML・JS/WebSocket・gRPC/F7567C)/BlazeMeter(Perforce/JMeter互換/クラウド大規模/E55200)/Vegeta(Go/CLI/固定レート/00C7B7)/hey(Go/シンプルCLI/旧Boom/0078D7)/NeoLoad(Tricentis/ノーコード/AIアシスト/FFC107)の9社追加(1825→1834社)。sitemap 1921→1930 URLs。perf-testingカテゴリ新設。',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
