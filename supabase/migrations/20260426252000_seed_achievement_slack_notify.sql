-- Issue #696 S2 + S3: core-hub:slack.notify + ai_circuit_breaker trigger 実装記録
-- Win版#132 part 36 / 2026-04-26
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Slack 連携 S2+S3: slack.notify + ai_circuit_breaker trigger 実装',
  'S2: core-hub に slack.notify action 追加 (6 channel · SLACK_WEBHOOK_* env 切替)。S3: ai_circuit_breaker.state closed→open 遷移時に Postgres trigger + pg_net.http_post 経由で core-hub:slack.notify (channel=quota) を呼び出す。Vault に service_role_key 保存が必要 (manual setup)。Issue #696 backlog から S2+S3 完了。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
