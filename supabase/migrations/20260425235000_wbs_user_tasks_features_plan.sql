-- PS#2 S25: user tasks feature plan記録
-- 実装済み: notify_user_tasks (tools-hub) + GHA wbs-user-tasks-notify.yml
-- 残: NotebookLM蓄積 (→PS#3) + Flutter UI (→VSCode版)
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'WBS user tasks 機能設計 (PS#2 S25)',
  'Slack通知済み(Win#132-18) / 重複casefix / NotebookLM→PS#3 / Flutter UI→VSCode 各cross-instance-pr発行',
  '2026-04-25'
)
ON CONFLICT DO NOTHING;
