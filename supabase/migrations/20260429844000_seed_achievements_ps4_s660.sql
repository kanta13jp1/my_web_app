-- PS#4 S660: 競合3社追加 メッセージキュー (kafka/pulsar/activemq)
-- SEO: "Apache Kafka代替"/"Apache Pulsar代替"/"ActiveMQ代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S660: 競合3社追加 (kafka/pulsar/activemq)',
  'comparison_page.dartにkafka(Apache 分散イベントストリーミング・高スループット・耐障害性/231F20)/pulsar(Apache マルチテナントメッセージング・地理分散・階層型ストレージ/188FFF)/activemq(Apache JMSブローカー・AMQP/STOMP/MQTT・Java/Spring統合/8A2BE2)の3社追加(1807社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
