-- Issue #696 S2: core-hub:slack.notify action 実装記録
-- Win版#132 part 36 / 2026-04-26
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'Slack 連携 S2: core-hub:slack.notify action 実装',
  'docs/DEV_PROCESS_MULTI_AI.md §8-4 設計に基づき core-hub に slack.notify action を追加。default/quota/ci/alerts/daily/handoff の 6 channel を SLACK_WEBHOOK_* env で切替。Issue #696 backlog から S2 完了。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
