-- PS#1 S22: CI triage + Rule 17 WF health check (2026-05-01)

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'PS#1 S22: CI triage + Rule 17 WF health check (2026-05-01)',
  '#1465クローズ (wbs_tasks_instance_check constraint violation / codex2 instance → Codex#2 PR #1464 fix確認) + Migration Time-Relative CHECK false-positive fix (-- nocheck: time-relative exemption追加 / scripts/check_migration_time_relative_check.py) + codex/* orphan 17→10本削除 (merged PR 7本) + Rule 17 WF health: 87% success / 1602 migrations 0 collision / timeout-minutes 正常 / deploy-prod cancel-in-progress: false 確認.',
  '2026-05-01'
)
ON CONFLICT DO NOTHING;
