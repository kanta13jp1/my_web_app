-- PS#4 S262: 競合3社追加 657→660社 (meilisearch/rabbitmq/hightouch)
-- SEO: "Meilisearch代替"/"RabbitMQ代替"/"Hightouch代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S262: 競合3社追加 657→660社 (meilisearch/rabbitmq/hightouch)',
  'comparison_page.dartにmeilisearch(OSS高速全文検索/search/FF5CAA)/rabbitmq(AMQP OSS メッセージブローカー/queue/FF6600)/hightouch(リバースETL/data-pipeline/7B61FF)の3社追加(657→660社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
