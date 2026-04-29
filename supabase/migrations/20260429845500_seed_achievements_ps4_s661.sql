-- PS#4 S661: 競合3社追加 タスクキュー/ジョブ (celery/bullmq/sqs)
-- SEO: "Celery代替"/"BullMQ代替"/"Amazon SQS代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S661: 競合3社追加 (celery/bullmq/sqs)',
  'comparison_page.dartにcelery(Python分散タスクキュー・非同期処理・スケジューラー・Redis/RabbitMQ/37814A)/bullmq(Node.js Redisジョブキュー・優先度・遅延・TypeScript/FF6B6B)/sqs(Amazon SQSマネージドMQ・FIFO・デッドレター/FF9900)の3社追加(1807社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
