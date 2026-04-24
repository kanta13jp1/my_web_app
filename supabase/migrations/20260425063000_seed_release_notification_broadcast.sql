-- PS#5 S44: notification.broadcast_release action added to core-hub
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'リリース通知 fan-out 実装 (#515)',
  'core-hub EF に notification.broadcast_release action 追加 (Service Role Key 認証 / idempotency / 過去90日アクティブユーザー全員に feature_update 通知一括配信) + deploy-prod.yml に broadcast curl step 追加 (continue-on-error: true)',
  '2026-04-24'
)
ON CONFLICT DO NOTHING;
